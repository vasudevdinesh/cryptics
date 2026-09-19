// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title HoneypotInjector
/// @notice Manages honeypot (known-answer) rounds.
contract HoneypotInjector is Ownable {
    mapping(uint256 => bytes32) public honeypotHashes;
    mapping(uint256 => bool) public isHoneypotRound;
    mapping(uint256 => bool) public honeypotRevealed;
    mapping(uint256 => uint256) public honeypotTruePrices;
    
    uint256 public slashPercent = 30; // 30%
    uint256 public deviationTolerance = 0.05e18; // 5%
    address public disputeModule;
    
    error Unauthorized();
    error InvalidHash();
    error NotRevealed();
    
    event HoneypotInjected(uint256 roundId);
    event HoneypotRevealed(uint256 roundId, uint256 truePrice);
    event JurorCaughtByHoneypot(address juror, uint256 deviation);

    modifier onlyDisputeModule() {
        if (msg.sender != disputeModule) revert Unauthorized();
        _;
    }

    constructor() Ownable(msg.sender) {}
    
    /// @notice Set dispute module address.
    function setDisputeModule(address _module) external onlyOwner {
        disputeModule = _module;
    }
    
    /// @notice Set slash percent.
    function setSlashPercent(uint256 percent) external onlyOwner {
        slashPercent = percent;
    }
    
    /// @notice Set deviation tolerance.
    function setDeviationTolerance(uint256 tol) external onlyOwner {
        deviationTolerance = tol;
    }
    
    /// @notice Inject a honeypot.
    function injectHoneypot(uint256 roundId, bytes32 truePriceHash) external onlyOwner {
        honeypotHashes[roundId] = truePriceHash;
        isHoneypotRound[roundId] = true;
        emit HoneypotInjected(roundId);
    }
    
    /// @notice Reveal honeypot answer.
    function revealHoneypot(uint256 roundId, uint256 truePrice, bytes32 salt) external onlyOwner {
        if (keccak256(abi.encodePacked(truePrice, salt)) != honeypotHashes[roundId]) {
            revert InvalidHash();
        }
        honeypotTruePrices[roundId] = truePrice;
        honeypotRevealed[roundId] = true;
        emit HoneypotRevealed(roundId, truePrice);
    }
    
    /// @notice Check if a round is a honeypot.
    function isHoneypot(uint256 roundId) external view onlyDisputeModule returns (bool) {
        return isHoneypotRound[roundId];
    }
    
    /// @notice Get honeypot true price.
    function getHoneypotTruePrice(uint256 roundId) external view returns (uint256) {
        if (!honeypotRevealed[roundId]) revert NotRevealed();
        return honeypotTruePrices[roundId];
    }
    
    /// @notice Evaluate a juror's performance in a honeypot.
    function evaluateJuror(uint256 roundId, uint256 jurorPrice) external view returns (bool passed, uint256 deviation) {
        if (!honeypotRevealed[roundId]) revert NotRevealed();
        uint256 truePrice = honeypotTruePrices[roundId];
        
        uint256 diff = jurorPrice > truePrice ? jurorPrice - truePrice : truePrice - jurorPrice;
        deviation = (diff * 1e18) / truePrice;
        passed = deviation <= deviationTolerance;
    }
}
