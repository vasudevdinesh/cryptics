// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IJurorRegistry} from "../interfaces/IJurorRegistry.sol";

/// @title Spot Check Panel
/// @notice Manages lightweight 2-3 juror panels for Tier 1 review
contract SpotCheckPanel is Ownable {
    /// @notice Defines the current status of a spot check
    enum SpotCheckStatus { Pending, Approved, Rejected, Escalated, Expired }

    /// @notice Struct maintaining spot check state
    struct SpotCheck {
        uint256 roundId;
        uint256 candidatePrice;
        uint256 startTime;
        address[] panelMembers;
        mapping(address => bool) hasVoted;
        mapping(address => bool) approvals;
        uint256 approveCount;
        uint256 rejectCount;
        SpotCheckStatus status;
    }

    /// @notice Custom errors
    error InvalidPanelSize();
    error NotPanelMember();
    error AlreadyVoted();
    error SpotCheckNotPending();
    error VotingWindowExpired();
    error InvalidConfiguration();

    /// @notice The juror registry dependency
    IJurorRegistry public jurorRegistry;

    /// @notice Number of jurors in a panel
    uint256 public panelSize = 3;

    /// @notice Votes required for an approval
    uint256 public approvalQuorum = 2;

    /// @notice Duration allowed for voting on a spot check
    uint256 public votingWindow = 300; // 5 minutes

    uint256 private _nextCheckId = 1;
    mapping(uint256 => SpotCheck) private _spotChecks;

    /// @notice Emitted when a spot check is initiated
    event SpotCheckInitiated(uint256 indexed roundId, uint256 indexed checkId, address[] selectedJurors);

    /// @notice Emitted when a vote is cast by a panel member
    event SpotCheckVoteCast(uint256 indexed checkId, address indexed juror, bool approve);

    /// @notice Emitted when a spot check resolves its status
    event SpotCheckFinalized(uint256 indexed checkId, SpotCheckStatus status);

    /// @notice Constructor
    /// @param _jurorRegistry Address of the Juror Registry
    constructor(address _jurorRegistry) Ownable(msg.sender) {
        jurorRegistry = IJurorRegistry(_jurorRegistry);
    }

    /// @notice Initiates a spot check process for a candidate price
    /// @param roundId The context round identifier
    /// @param candidatePrice The proposed price undergoing check
    /// @param selectedJurors The list of addresses comprising the panel
    /// @return checkId The ID assigned to the spot check
    function initiateSpotCheck(uint256 roundId, uint256 candidatePrice, address[] calldata selectedJurors) external returns (uint256 checkId) {
        if (selectedJurors.length != panelSize) revert InvalidPanelSize();

        for (uint256 i = 0; i < selectedJurors.length; i++) {
            require(jurorRegistry.isEligible(selectedJurors[i]), "Juror not eligible");
        }

        checkId = _nextCheckId++;
        SpotCheck storage check = _spotChecks[checkId];
        check.roundId = roundId;
        check.candidatePrice = candidatePrice;
        check.startTime = block.timestamp;
        check.panelMembers = selectedJurors;
        check.status = SpotCheckStatus.Pending;

        emit SpotCheckInitiated(roundId, checkId, selectedJurors);
    }

    /// @notice Allows an appointed juror to cast their vote
    /// @param checkId The ID of the spot check to vote on
    /// @param approve Boolean indicating whether to approve (true) or reject (false)
    function vote(uint256 checkId, bool approve) external {
        SpotCheck storage check = _spotChecks[checkId];
        if (check.status != SpotCheckStatus.Pending) revert SpotCheckNotPending();
        if (block.timestamp > check.startTime + votingWindow) revert VotingWindowExpired();

        bool isMember = false;
        for (uint256 i = 0; i < check.panelMembers.length; i++) {
            if (check.panelMembers[i] == msg.sender) {
                isMember = true;
                break;
            }
        }
        if (!isMember) revert NotPanelMember();
        if (check.hasVoted[msg.sender]) revert AlreadyVoted();

        check.hasVoted[msg.sender] = true;
        check.approvals[msg.sender] = approve;

        if (approve) {
            check.approveCount++;
        } else {
            check.rejectCount++;
        }

        emit SpotCheckVoteCast(checkId, msg.sender, approve);

        if (check.approveCount >= approvalQuorum) {
            check.status = SpotCheckStatus.Approved;
            emit SpotCheckFinalized(checkId, check.status);
        } else if (check.rejectCount > panelSize - approvalQuorum) {
            check.status = SpotCheckStatus.Escalated;
            emit SpotCheckFinalized(checkId, check.status);
        }
    }

    /// @notice Finalizes a spot check after its voting window has expired
    /// @param checkId The ID of the spot check to finalize
    function finalizeSpotCheck(uint256 checkId) external {
        SpotCheck storage check = _spotChecks[checkId];
        if (check.status != SpotCheckStatus.Pending) revert SpotCheckNotPending();
        
        if (block.timestamp <= check.startTime + votingWindow) {
            // Cannot finalize before expiration unless quorum is reached during voting
            return;
        }

        if (check.approveCount >= approvalQuorum) {
            check.status = SpotCheckStatus.Approved;
        } else {
            check.status = SpotCheckStatus.Escalated;
        }

        emit SpotCheckFinalized(checkId, check.status);
    }

    /// @notice Returns the status of a specific spot check
    /// @param checkId The spot check ID
    /// @return The status of the spot check
    function getSpotCheckStatus(uint256 checkId) external view returns (SpotCheckStatus) {
        return _spotChecks[checkId].status;
    }

    /// @notice Sets the number of jurors in a spot check panel
    /// @param _panelSize The new panel size
    function setPanelSize(uint256 _panelSize) external onlyOwner {
        if (_panelSize == 0) revert InvalidConfiguration();
        panelSize = _panelSize;
    }

    /// @notice Sets the required number of approvals to pass a spot check
    /// @param _approvalQuorum The new approval quorum
    function setApprovalQuorum(uint256 _approvalQuorum) external onlyOwner {
        if (_approvalQuorum == 0 || _approvalQuorum > panelSize) revert InvalidConfiguration();
        approvalQuorum = _approvalQuorum;
    }

    /// @notice Sets the voting window duration for spot checks
    /// @param _votingWindow The new voting duration in seconds
    function setVotingWindow(uint256 _votingWindow) external onlyOwner {
        if (_votingWindow == 0) revert InvalidConfiguration();
        votingWindow = _votingWindow;
    }
}
