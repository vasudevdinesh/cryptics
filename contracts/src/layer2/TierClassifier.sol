// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ITierClassifier} from "../interfaces/ITierClassifier.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Tier Classifier
/// @notice Classifies price updates into tiers based on deviation
contract TierClassifier is ITierClassifier, Ownable {
    /// @notice Custom error for invalid price inputs
    error InvalidPrice();
    /// @notice Custom error for invalid threshold configuration
    error InvalidThresholds();

    uint256 private _thetaTier1 = 0.03e18; // 3% deviation
    uint256 private _thetaTier2 = 0.10e18; // 10% deviation
    
    /// @notice The current round ID
    uint256 public currentRoundId;


    /// @notice Constructor
    constructor() Ownable(msg.sender) {}

    /// @notice Classifies a price update into a tier, emitting an event and incrementing the round ID
    /// @param candidatePrice The proposed new price
    /// @param currentPrice The current accepted price
    /// @return The resulting tier classification
    function classify(uint256 candidatePrice, uint256 currentPrice) external returns (Tier) {
        if (currentPrice == 0 || candidatePrice == 0) revert InvalidPrice();

        (Tier tier, uint256 deviation) = classifyView(candidatePrice, currentPrice);
        
        emit TierClassified(currentRoundId, tier, deviation);
        currentRoundId++;
        
        return tier;
    }

    /// @notice View function to classify a price update into a tier without state changes
    /// @param candidatePrice The proposed new price
    /// @param currentPrice The current accepted price
    /// @return The resulting tier classification and the deviation
    function classifyView(uint256 candidatePrice, uint256 currentPrice) public view returns (Tier, uint256) {
        if (currentPrice == 0 || candidatePrice == 0) revert InvalidPrice();

        uint256 diff = candidatePrice > currentPrice ? candidatePrice - currentPrice : currentPrice - candidatePrice;
        uint256 deviation = (diff * 1e18) / currentPrice;

        if (deviation < _thetaTier1) {
            return (Tier.NORMAL, deviation);
        } else if (deviation < _thetaTier2) {
            return (Tier.MODERATE, deviation);
        } else {
            return (Tier.CRITICAL, deviation);
        }
    }

    /// @notice Gets the threshold for Tier 1
    /// @return The Tier 1 threshold deviation
    function thetaTier1() external view returns (uint256) {
        return _thetaTier1;
    }

    /// @notice Gets the threshold for Tier 2
    /// @return The Tier 2 threshold deviation
    function thetaTier2() external view returns (uint256) {
        return _thetaTier2;
    }

    /// @notice Sets the thresholds for tier classifications
    /// @param newTheta1 The new Tier 1 threshold
    /// @param newTheta2 The new Tier 2 threshold
    function setThresholds(uint256 newTheta1, uint256 newTheta2) external onlyOwner {
        if (newTheta1 >= newTheta2) revert InvalidThresholds();
        _thetaTier1 = newTheta1;
        _thetaTier2 = newTheta2;
    }
}
