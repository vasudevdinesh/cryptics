// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IJurorRegistry
/// @notice Interface for the shared cross-protocol juror pool with bonding and reputation.
interface IJurorRegistry {
    /// @notice Juror data structure
    struct JurorData {
        address juror;
        uint256 bondAmount;       // Total bonded ETH
        uint256 weight;           // Current reputation weight (scaled 1e18)
        uint256 vestedWeight;     // Portion of weight that is fully vested
        uint256 unvestedGains;    // Weight gains still vesting
        uint256 vestingStartBlock;// Block when current vesting began
        uint256 totalDisputes;    // Number of disputes participated in
        uint256 lastActiveRound;  // Last round participated in
        bool registered;          // Whether juror is registered
    }

    /// @notice Register as a juror by bonding ETH.
    function register() external payable;

    /// @notice Add additional bond.
    function bond() external payable;

    /// @notice Withdraw bond (subject to timelock).
    /// @param amount Amount of ETH to withdraw.
    function unbond(uint256 amount) external;

    /// @notice Get the effective weight of a juror (accounting for vesting).
    /// @param juror Address of the juror.
    /// @return effectiveWeight The current effective voting weight.
    function getEffectiveWeight(address juror) external view returns (uint256 effectiveWeight);

    /// @notice Update a juror's weight after a round (called by DisputeModule).
    /// @param juror Address of the juror.
    /// @param roundScore Score from the round (scaled 1e18).
    function updateWeight(address juror, uint256 roundScore) external;

    /// @notice Slash a juror's bond.
    /// @param juror Address of the juror.
    /// @param amount Amount to slash.
    function slash(address juror, uint256 amount) external;

    /// @notice Check if a juror is eligible for selection.
    /// @param juror Address of the juror.
    /// @return True if eligible.
    function isEligible(address juror) external view returns (bool);

    /// @notice Get full juror data.
    /// @param juror Address of the juror.
    /// @return data The complete juror data struct.
    function getJurorData(address juror) external view returns (JurorData memory data);

    /// @notice Get all registered juror addresses.
    /// @return addresses Array of registered juror addresses.
    function getJurors() external view returns (address[] memory addresses);

    event JurorRegistered(address indexed juror, uint256 bondAmount);
    event BondDeposited(address indexed juror, uint256 amount, uint256 totalBond);
    event BondWithdrawn(address indexed juror, uint256 amount, uint256 remaining);
    event WeightUpdated(address indexed juror, uint256 oldWeight, uint256 newWeight);
    event JurorSlashed(address indexed juror, uint256 amount, uint256 remainingBond);
}
