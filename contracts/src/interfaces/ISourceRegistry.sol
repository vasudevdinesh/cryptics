// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISourceRegistry
/// @notice Interface for managing data source reputation and registration.
interface ISourceRegistry {
    /// @notice Source data structure
    struct SourceData {
        address source;
        uint256 reputation;      // Scaled 1e18, range [MIN_REPUTATION, 1e18]
        uint256 lastUpdateTime;  // Timestamp of last price submission
        uint256 totalReports;    // Total number of price reports
        uint8 venueId;           // Methodologically independent venue identifier
        bool active;             // Whether source is currently active
    }

    /// @notice Registers a new data source with a venue identifier.
    /// @param source Address of the off-chain data source.
    /// @param venueId Independent venue identifier.
    function registerSource(address source, uint8 venueId) external;

    /// @notice Records a price submission from a source.
    /// @param source Address of the reporting source.
    /// @param price The submitted price (scaled 1e18).
    function reportPrice(address source, uint256 price) external;

    /// @notice Updates a source's reputation after the resolved truth is known.
    /// @param source Address of the source.
    /// @param resolvedPrice The ground-truth price for the round.
    function updateReputation(address source, uint256 resolvedPrice) external;

    /// @notice Returns the reputation score for a source.
    /// @param source Address of the source.
    /// @return reputation The current reputation (scaled 1e18).
    function getReputation(address source) external view returns (uint256 reputation);

    /// @notice Returns whether a source is active and meets minimum reputation.
    /// @param source Address of the source.
    /// @return True if source is active and above minimum reputation.
    function isActive(address source) external view returns (bool);

    /// @notice Returns full source data.
    /// @param source Address of the source.
    /// @return data The complete source data struct.
    function getSourceData(address source) external view returns (SourceData memory data);

    event SourceRegistered(address indexed source, uint8 venueId);
    event PriceReported(address indexed source, uint256 price, uint256 timestamp);
    event ReputationUpdated(address indexed source, uint256 oldReputation, uint256 newReputation);
    event SourceDeactivated(address indexed source, string reason);
    event SourceReactivated(address indexed source);
}
