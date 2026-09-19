// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IJurorRegistry} from "../interfaces/IJurorRegistry.sol";
import {IResolvedPrice} from "../interfaces/IResolvedPrice.sol";
import {RandomSelector} from "./RandomSelector.sol";
import {DeviationCap} from "./DeviationCap.sol";
import {HoneypotInjector} from "./HoneypotInjector.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DisputeModule
/// @notice Central contract for Tier 2 dispute resolution.
contract DisputeModule is IResolvedPrice, Ownable, ReentrancyGuard {
    enum Phase { Idle, CommitPhase, RevealPhase, Scoring, Resolved, TimedOut }

    struct Dispute {
        uint256 roundId;
        uint256 disputedPrice;
        Phase phase;
        uint256 commitDeadline;
        uint256 revealDeadline;
        address[] jury;
        uint256 commitCount;
        uint256 revealCount;
        uint256 resolvedPrice;
        bool isHoneypot;
        uint256 honeypotTruePrice;
    }

    IJurorRegistry public jurorRegistry;
    RandomSelector public randomSelector;
    DeviationCap public deviationCap;
    HoneypotInjector public honeypotInjector;
    
    uint256 public lastConfirmedPrice;
    uint256 public currentDisputeId;
    mapping(uint256 => Dispute) public disputes;
    
    mapping(uint256 => mapping(address => bytes32)) public disputeCommits;
    mapping(uint256 => mapping(address => uint256)) public disputeRevealedPrices;
    mapping(uint256 => mapping(address => uint256)) public disputePeerPredictions;
    mapping(uint256 => mapping(address => bool)) public disputeHasCommitted;
    mapping(uint256 => mapping(address => bool)) public disputeHasRevealed;

    uint256 public commitWindow = 300;
    uint256 public revealWindow = 300;
    uint256 public trimPercent = 20;
    bool public disputeActive;

    error Unauthorized();
    error InvalidPhase();
    error NotSelectedJuror();
    error AlreadyCommitted();
    error AlreadyRevealed();
    error InvalidHash();
    error DisputedRound();
    error NotReadyToResolve();

    event DisputeInitiated(uint256 indexed disputeId, uint256 roundId, uint256 disputedPrice);
    event VoteCommitted(uint256 indexed disputeId, address indexed juror);
    event VoteRevealed(uint256 indexed disputeId, address indexed juror, uint256 price, uint256 prediction);
    event DisputeResolved(uint256 indexed disputeId, uint256 resolvedPrice);
    event JurorScored(uint256 indexed disputeId, address indexed juror, uint256 score);
    event FallbackActivated(uint256 indexed disputeId, uint256 fallbackPrice);

    constructor(
        address _jurorRegistry,
        address _randomSelector,
        address _deviationCap,
        address _honeypotInjector
    ) Ownable(msg.sender) {
        jurorRegistry = IJurorRegistry(_jurorRegistry);
        randomSelector = RandomSelector(_randomSelector);
        deviationCap = DeviationCap(_deviationCap);
        honeypotInjector = HoneypotInjector(_honeypotInjector);
    }

    function setCommitWindow(uint256 _win) external onlyOwner {
        commitWindow = _win;
    }

    function setRevealWindow(uint256 _win) external onlyOwner {
        revealWindow = _win;
    }

    function setTrimPercent(uint256 _percent) external onlyOwner {
        trimPercent = _percent;
    }

    /// @notice Initiate a dispute for a price round.
    function initiateDispute(uint256 roundId, uint256 disputedPrice) external {
        // Assume callable by any authorized gateway, keeping it open for now or we can add authorization
        currentDisputeId++;
        uint256 dId = currentDisputeId;
        
        disputes[dId].roundId = roundId;
        disputes[dId].disputedPrice = disputedPrice;
        disputes[dId].phase = Phase.CommitPhase;
        disputes[dId].commitDeadline = block.timestamp + commitWindow;
        
        disputeActive = true;
        randomSelector.requestJurySelection(roundId, randomSelector.defaultJurySize());
        
        emit DisputeInitiated(dId, roundId, disputedPrice);
    }

    function isSelectedJuror(uint256 disputeId, address juror) internal view returns (bool) {
        uint256 rId = disputes[disputeId].roundId;
        if (!randomSelector.jurySealed(rId)) return false;
        address[] memory jury = randomSelector.getSelectedJury(rId);
        for (uint256 i = 0; i < jury.length; i++) {
            if (jury[i] == juror) return true;
        }
        return false;
    }

    /// @notice Commit a hashed vote.
    function commitVote(uint256 disputeId, bytes32 commitHash) external {
        Dispute storage d = disputes[disputeId];
        if (d.phase != Phase.CommitPhase) revert InvalidPhase();
        if (block.timestamp > d.commitDeadline) {
            d.phase = Phase.RevealPhase;
            d.revealDeadline = block.timestamp + revealWindow;
            revert InvalidPhase();
        }
        if (!isSelectedJuror(disputeId, msg.sender)) revert NotSelectedJuror();
        if (disputeHasCommitted[disputeId][msg.sender]) revert AlreadyCommitted();

        disputeCommits[disputeId][msg.sender] = commitHash;
        disputeHasCommitted[disputeId][msg.sender] = true;
        d.commitCount++;

        emit VoteCommitted(disputeId, msg.sender);
    }

    /// @notice Reveal a committed vote.
    function revealVote(uint256 disputeId, uint256 price, uint256 peerPrediction, bytes32 salt) external {
        Dispute storage d = disputes[disputeId];
        if (block.timestamp > d.commitDeadline && d.phase == Phase.CommitPhase) {
            d.phase = Phase.RevealPhase;
            d.revealDeadline = block.timestamp + revealWindow;
        }
        if (d.phase != Phase.RevealPhase) revert InvalidPhase();
        if (block.timestamp > d.revealDeadline) revert InvalidPhase();
        
        if (!disputeHasCommitted[disputeId][msg.sender]) revert Unauthorized();
        if (disputeHasRevealed[disputeId][msg.sender]) revert AlreadyRevealed();
        
        bytes32 expectedHash = keccak256(abi.encodePacked(price, peerPrediction, salt));
        if (expectedHash != disputeCommits[disputeId][msg.sender]) revert InvalidHash();

        disputeRevealedPrices[disputeId][msg.sender] = price;
        disputePeerPredictions[disputeId][msg.sender] = peerPrediction;
        disputeHasRevealed[disputeId][msg.sender] = true;
        d.revealCount++;

        emit VoteRevealed(disputeId, msg.sender, price, peerPrediction);
    }

    function sortArray(uint256[] memory arr) internal pure {
        uint256 l = arr.length;
        for (uint256 i = 0; i < l; i++) {
            for (uint256 j = i + 1; j < l; j++) {
                if (arr[i] > arr[j]) {
                    uint256 temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }
    }

    /// @notice Resolve the dispute.
    function resolveDispute(uint256 disputeId) external nonReentrant {
        Dispute storage d = disputes[disputeId];
        if (block.timestamp > d.commitDeadline && d.phase == Phase.CommitPhase) {
            d.phase = Phase.RevealPhase;
            d.revealDeadline = block.timestamp + revealWindow;
        }
        if (d.phase != Phase.RevealPhase) revert InvalidPhase();
        if (block.timestamp <= d.revealDeadline) revert NotReadyToResolve();

        address[] memory jury = randomSelector.getSelectedJury(d.roundId);
        uint256[] memory rPrices = new uint256[](d.revealCount);
        address[] memory rJurors = new address[](d.revealCount);
        
        uint256 idx = 0;
        for (uint256 i = 0; i < jury.length; i++) {
            if (disputeHasRevealed[disputeId][jury[i]]) {
                rPrices[idx] = disputeRevealedPrices[disputeId][jury[i]];
                rJurors[idx] = jury[i];
                idx++;
            }
        }

        if (d.revealCount == 0) {
            handleTimeout(disputeId);
            return;
        }

        sortArray(rPrices);
        uint256 trimCount = (rPrices.length * trimPercent) / 100;
        uint256 resPrice;
        if (rPrices.length > trimCount * 2) {
            uint256 mid = (rPrices.length - trimCount * 2) / 2 + trimCount;
            resPrice = rPrices[mid];
        } else {
            resPrice = rPrices[rPrices.length / 2];
        }

        (uint256 clampedPrice, ) = deviationCap.clamp(resPrice, lastConfirmedPrice);
        d.resolvedPrice = clampedPrice;
        
        bool isHoney = honeypotInjector.isHoneypot(d.roundId);
        d.isHoneypot = isHoney;
        
        for (uint256 i = 0; i < rJurors.length; i++) {
            _processJurorScoring(disputeId, rJurors[i], clampedPrice, isHoney);
        }

        lastConfirmedPrice = clampedPrice;
        d.phase = Phase.Resolved;
        disputeActive = false;
        
        emit DisputeResolved(disputeId, clampedPrice);
    }

    /// @notice Handle timeout if not enough reveals.
    function _processJurorScoring(
        uint256 disputeId,
        address j,
        uint256 clampedPrice,
        bool isHoney
    ) internal {
        uint256 jPrice = disputeRevealedPrices[disputeId][j];
        uint256 jPred = disputePeerPredictions[disputeId][j];
        
        uint256 pDiff = jPred > jPrice ? jPred - jPrice : jPrice - jPred;
        uint256 rDiff = jPrice > clampedPrice ? jPrice - clampedPrice : clampedPrice - jPrice;
        
        uint256 accScore = 1e18;
        uint256 denom = clampedPrice > 0 ? clampedPrice : 1;
        uint256 errorPenalty = (rDiff * 1e18) / denom;
        if (errorPenalty > 1e18) errorPenalty = 1e18;
        accScore -= errorPenalty;
        
        uint256 infoBonus = 0;
        if (pDiff > rDiff) {
            infoBonus = ((pDiff - rDiff) * 1e18) / denom;
            if (infoBonus > 1e18) infoBonus = 1e18;
        }
        
        uint256 roundScore = (accScore * 7 + infoBonus * 3) / 10;
        jurorRegistry.updateWeight(j, roundScore);
        emit JurorScored(disputeId, j, roundScore);

        if (isHoney) {
            // If this is a honeypot, check if juror deviated beyond tolerance and slash
            (bool passed, ) = honeypotInjector.evaluateJuror(disputes[disputeId].roundId, jPrice);
            if (!passed) {
                // Slash 30% of their bond
                uint256 bond = jurorRegistry.getJurorData(j).bondAmount;
                uint256 slashAmt = (bond * honeypotInjector.slashPercent()) / 100;
                if (slashAmt > 0) {
                    jurorRegistry.slash(j, slashAmt);
                }
            }
        }
    }

    function handleTimeout(uint256 disputeId) public {
        Dispute storage d = disputes[disputeId];
        d.phase = Phase.TimedOut;
        d.resolvedPrice = lastConfirmedPrice; // Fallback to last confirmed
        lastConfirmedPrice = lastConfirmedPrice; 
        disputeActive = false;
        emit FallbackActivated(disputeId, lastConfirmedPrice);
    }

    /// @notice Read the current resolved price.
    function read() external view override returns (uint256 price, bool disputed) {
        return (lastConfirmedPrice, disputeActive);
    }
}
