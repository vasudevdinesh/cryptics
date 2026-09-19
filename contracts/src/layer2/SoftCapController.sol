// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Soft Cap Controller
/// @notice Bounds the rate-of-change during Tier 1 updates
contract SoftCapController is Ownable {
    /// @notice Max rate of change per update
    uint256 public maxRateOfChange = 0.05e18; // 5% max move
    
    /// @notice The last confirmed valid price
    uint256 public lastConfirmedPrice;
    
    /// @notice The timestamp of the last confirmed price
    uint256 public lastConfirmedTimestamp;
    
    /// @notice Whether the soft cap was applied during the last update
    bool public softCapActive;

    /// @notice Emitted when the soft cap restricts the price change
    event SoftCapApplied(uint256 indexed candidatePrice, uint256 cappedPrice, uint256 currentPrice);
    
    /// @notice Emitted when a price is fully confirmed
    event PriceConfirmed(uint256 indexed price);

    /// @notice Constructor
    constructor() Ownable(msg.sender) {}

    /// @notice Applies the soft cap bounds to the candidate price relative to the current price
    /// @param candidatePrice The proposed price
    /// @param currentPrice The current base price
    /// @return cappedPrice The price bounded by the soft cap limits
    /// @return wasCapped Boolean indicating if the soft cap limit was hit
    function applySoftCap(uint256 candidatePrice, uint256 currentPrice) external returns (uint256 cappedPrice, bool wasCapped) {
        uint256 maxMove = (currentPrice * maxRateOfChange) / 1e18;
        
        uint256 diff = candidatePrice > currentPrice ? candidatePrice - currentPrice : currentPrice - candidatePrice;

        if (diff <= maxMove) {
            cappedPrice = candidatePrice;
            wasCapped = false;
        } else if (candidatePrice > currentPrice) {
            cappedPrice = currentPrice + maxMove;
            wasCapped = true;
        } else {
            cappedPrice = currentPrice - maxMove;
            wasCapped = true;
        }

        lastConfirmedPrice = cappedPrice;
        lastConfirmedTimestamp = block.timestamp;
        softCapActive = wasCapped;

        if (wasCapped) {
            emit SoftCapApplied(candidatePrice, cappedPrice, currentPrice);
        }

        return (cappedPrice, wasCapped);
    }

    /// @notice Confirms a price directly without bounding and clears the soft cap flag
    /// @param price The price to confirm
    function confirmPrice(uint256 price) external {
        lastConfirmedPrice = price;
        lastConfirmedTimestamp = block.timestamp;
        softCapActive = false;
        
        emit PriceConfirmed(price);
    }

    /// @notice Updates the maximum allowable rate of change
    /// @param newRate The new max rate of change in 1e18 precision
    function setMaxRateOfChange(uint256 newRate) external onlyOwner {
        maxRateOfChange = newRate;
    }

    /// @notice View function to check if the soft cap is currently active
    /// @return True if the soft cap was hit on the last update, false otherwise
    function isSoftCapActive() external view returns (bool) {
        return softCapActive;
    }
}
