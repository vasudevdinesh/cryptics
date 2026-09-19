// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ITierClassifier
/// @notice Interface for classifying price rounds into tiers based on deviation.
interface ITierClassifier {
    /// @notice Tier levels for price deviation classification
    enum Tier {
        NORMAL,    // Tier 0: deviation within normal bounds
        MODERATE,  // Tier 1: moderate deviation, soft-cap + spot-check
        CRITICAL   // Tier 2: severe deviation, full halt + jury resolution
    }

    /// @notice Classifies a candidate price into a tier, increments roundId and emits event.
    /// @param candidatePrice The proposed new price (scaled 1e18).
    /// @param currentPrice The current confirmed price (scaled 1e18).
    /// @return tier The classification result.
    function classify(uint256 candidatePrice, uint256 currentPrice) external returns (Tier tier);

    /// @notice View-only classification without state changes.
    /// @param candidatePrice The proposed new price (scaled 1e18).
    /// @param currentPrice The current confirmed price (scaled 1e18).
    /// @return tier The classification result.
    /// @return deviation The absolute deviation scaled 1e18.
    function classifyView(uint256 candidatePrice, uint256 currentPrice) external view returns (Tier tier, uint256 deviation);

    /// @notice Returns the Tier 1 threshold.
    /// @return The θ_tier1 value (scaled 1e18, e.g., 3% = 0.03e18).
    function thetaTier1() external view returns (uint256);

    /// @notice Returns the Tier 2 threshold.
    /// @return The θ_tier2 value (scaled 1e18, e.g., 10% = 0.1e18).
    function thetaTier2() external view returns (uint256);

    event TierClassified(uint256 indexed roundId, Tier tier, uint256 deviation);
}
