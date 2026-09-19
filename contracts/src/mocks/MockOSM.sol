// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MockOSM
/// @notice Simulates the Oracle Security Module (OSM) with hop window behavior.
/// @dev For testing/demo purposes. Mimics the MakerDAO OSM's queued price updates.
contract MockOSM {
    uint256 private _currentPrice;
    uint256 private _nextPrice;
    uint256 private _lastUpdateTime;
    uint256 public hop; // Update interval in seconds
    bool private _hasNextPrice;

    error NotYetTime();
    error NoPriceQueued();
    error InvalidPrice();

    event PriceQueued(uint256 price, uint256 effectiveAt);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event HopUpdated(uint256 oldHop, uint256 newHop);

    /// @notice Initialize the MockOSM with an initial price and hop interval.
    /// @param initialPrice The starting price (scaled 1e18).
    /// @param _hop The update interval in seconds.
    constructor(uint256 initialPrice, uint256 _hop) {
        if (initialPrice == 0) revert InvalidPrice();
        _currentPrice = initialPrice;
        _lastUpdateTime = block.timestamp;
        hop = _hop;
    }

    /// @notice Queue a new price to take effect after the hop window.
    /// @param price The new price to queue (scaled 1e18).
    function poke(uint256 price) external {
        if (price == 0) revert InvalidPrice();
        _nextPrice = price;
        _hasNextPrice = true;
        emit PriceQueued(price, _lastUpdateTime + hop);
    }

    /// @notice Advance the price: move queued price to current if hop has elapsed.
    function step() external {
        if (!_hasNextPrice) revert NoPriceQueued();
        if (block.timestamp < _lastUpdateTime + hop) revert NotYetTime();

        uint256 oldPrice = _currentPrice;
        _currentPrice = _nextPrice;
        _hasNextPrice = false;
        _lastUpdateTime = block.timestamp;

        emit PriceUpdated(oldPrice, _currentPrice);
    }

    /// @notice Force-set the current price (for demo/testing only).
    /// @param price The price to set immediately.
    function forceSetPrice(uint256 price) external {
        if (price == 0) revert InvalidPrice();
        uint256 oldPrice = _currentPrice;
        _currentPrice = price;
        _lastUpdateTime = block.timestamp;
        emit PriceUpdated(oldPrice, price);
    }

    /// @notice Read the current price.
    /// @return price The current price (scaled 1e18).
    /// @return valid True if a price has been set.
    function read() external view returns (uint256 price, bool valid) {
        return (_currentPrice, _currentPrice > 0);
    }

    /// @notice Read the queued (next) price.
    /// @return price The queued price.
    /// @return hasNext True if a price is queued.
    function peekNext() external view returns (uint256 price, bool hasNext) {
        return (_nextPrice, _hasNextPrice);
    }

    /// @notice Update the hop interval.
    /// @param newHop New interval in seconds.
    function setHop(uint256 newHop) external {
        uint256 oldHop = hop;
        hop = newHop;
        emit HopUpdated(oldHop, newHop);
    }

    /// @notice Get the timestamp of the last price update.
    function lastUpdateTime() external view returns (uint256) {
        return _lastUpdateTime;
    }
}
