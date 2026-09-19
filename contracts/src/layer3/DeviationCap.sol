// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title DeviationCap
/// @notice Implements a hard ceiling on resolved price movement.
contract DeviationCap is Ownable {
    uint256 public maxDeviation = 0.15e18; // 15%
    
    error InvalidCap();

    event PriceClamped(uint256 resolvedPrice, uint256 clampedPrice, uint256 lastConfirmedPrice);
    
    constructor() Ownable(msg.sender) {}
    
    /// @notice Set the maximum deviation.
    function setMaxDeviation(uint256 newMax) external onlyOwner {
        if (newMax == 0 || newMax > 0.5e18) revert InvalidCap();
        maxDeviation = newMax;
    }
    
    /// @notice Clamp the resolved price based on max deviation.
    function clamp(uint256 resolvedPrice, uint256 lastConfirmedPrice) external returns (uint256 clampedPrice, bool wasClamped) {
        if (lastConfirmedPrice == 0) return (resolvedPrice, false);
        
        uint256 maxMove = (lastConfirmedPrice * maxDeviation) / 1e18;
        uint256 diff = resolvedPrice > lastConfirmedPrice ? resolvedPrice - lastConfirmedPrice : lastConfirmedPrice - resolvedPrice;
        
        if (diff <= maxMove) return (resolvedPrice, false);
        
        if (resolvedPrice > lastConfirmedPrice) {
            clampedPrice = lastConfirmedPrice + maxMove;
        } else {
            clampedPrice = lastConfirmedPrice - maxMove;
        }
        wasClamped = true;
        
        emit PriceClamped(resolvedPrice, clampedPrice, lastConfirmedPrice);
    }
}
