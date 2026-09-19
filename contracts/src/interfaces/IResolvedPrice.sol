// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IResolvedPrice
/// @notice Interface for reading the current resolved price from the RWJO system.
/// @dev Adapter reads DisputeModule.read() only while a Tier 2 dispute is active
///      or a Tier 1 soft-cap is in effect; otherwise reads OSM.read() unchanged.
///      Vat and Spot require zero modification.
interface IResolvedPrice {
    /// @notice Returns the current price and dispute status.
    /// @return price The current resolved price (scaled 1e18).
    /// @return disputed True if a dispute is currently active.
    function read() external view returns (uint256 price, bool disputed);
}
