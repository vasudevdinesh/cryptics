// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IJurorRegistry} from "../interfaces/IJurorRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IMockVRFCoordinator {
    function requestRandomWords(bytes32, uint256, uint16, uint32, uint32) external returns (uint256);
}

/// @title RandomSelector
/// @notice Selects jurors using VRF.
contract RandomSelector is Ownable {
    IJurorRegistry public jurorRegistry;
    address public vrfCoordinator;
    
    mapping(uint256 => uint256) public requestToRound;
    mapping(uint256 => address[]) public selectedJuries;
    mapping(uint256 => bool) public jurySealed;
    
    uint256 public defaultJurySize = 5;
    address public disputeModule;

    error Unauthorized();
    error NotSealed();

    event JurySelectionRequested(uint256 roundId, uint256 requestId);
    event JurySelected(uint256 roundId, address[] jurors);

    modifier onlyDisputeModule() {
        if (msg.sender != disputeModule) revert Unauthorized();
        _;
    }

    constructor(address _jurorRegistry, address _vrfCoordinator) Ownable(msg.sender) {
        jurorRegistry = IJurorRegistry(_jurorRegistry);
        vrfCoordinator = _vrfCoordinator;
    }

    /// @notice Set default jury size.
    function setJurySize(uint256 size) external onlyOwner {
        defaultJurySize = size;
    }

    /// @notice Set dispute module address.
    function setDisputeModule(address _module) external onlyOwner {
        disputeModule = _module;
    }

    /// @notice Request jury selection for a round.
    function requestJurySelection(uint256 roundId, uint256 jurySize) external onlyDisputeModule {
        uint256 requestId = IMockVRFCoordinator(vrfCoordinator).requestRandomWords(bytes32(0), 0, 0, 0, uint32(jurySize));
        requestToRound[requestId] = roundId;
        emit JurySelectionRequested(roundId, requestId);
    }

    /// @notice Fulfill random words and select jury.
    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        if (msg.sender != vrfCoordinator) revert Unauthorized();
        uint256 roundId = requestToRound[requestId];
        
        address[] memory allJurors = jurorRegistry.getJurors();
        uint256 eligibleCount = 0;
        
        for (uint256 i = 0; i < allJurors.length; i++) {
            if (jurorRegistry.isEligible(allJurors[i])) {
                eligibleCount++;
            }
        }
        
        address[] memory pool = new address[](eligibleCount);
        uint256[] memory weights = new uint256[](eligibleCount);
        uint256 totalWeight = 0;
        
        uint256 idx = 0;
        for (uint256 i = 0; i < allJurors.length; i++) {
            address j = allJurors[i];
            if (jurorRegistry.isEligible(j)) {
                pool[idx] = j;
                IJurorRegistry.JurorData memory data = jurorRegistry.getJurorData(j);
                uint256 w = (data.bondAmount * jurorRegistry.getEffectiveWeight(j)) / 1e18;
                weights[idx] = w;
                totalWeight += w;
                idx++;
            }
        }
        
        uint256 size = randomWords.length;
        if (size > eligibleCount) {
            size = eligibleCount;
        }
        
        address[] memory selected = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            if (totalWeight == 0) break;
            uint256 pick = randomWords[i] % totalWeight;
            uint256 acc = 0;
            
            for (uint256 j = 0; j < eligibleCount; j++) {
                if (weights[j] > 0) {
                    acc += weights[j];
                    if (pick < acc) {
                        selected[i] = pool[j];
                        totalWeight -= weights[j];
                        weights[j] = 0;
                        break;
                    }
                }
            }
        }
        
        selectedJuries[roundId] = selected;
        jurySealed[roundId] = true;
        
        emit JurySelected(roundId, selected);
    }

    /// @notice Get the selected jury.
    function getSelectedJury(uint256 roundId) external view returns (address[] memory) {
        if (!jurySealed[roundId]) revert NotSealed();
        return selectedJuries[roundId];
    }
}
