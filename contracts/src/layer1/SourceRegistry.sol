// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISourceRegistry} from "../interfaces/ISourceRegistry.sol";

error SourceAlreadyRegistered(address source);
error SourceNotRegistered(address source);
error InvalidAddress(address source);
error InvalidPrice(uint256 price);

/// @title SourceRegistry
/// @notice Implements layer 1 source registration and reputation management
contract SourceRegistry is ISourceRegistry, Ownable {
    uint256 public constant DEFAULT_REPUTATION = 0.5e18;
    uint256 public constant DECAY_RATE = 0.001e18;

    uint256 public minReputation = 0.1e18;
    uint256 public reputationAlpha = 0.1e18;
    uint256 public stalenessThreshold = 3600;

    mapping(address => SourceData) public sources;
    address[] public sourceList;
    mapping(address => uint256) public lastReportedPrice;
    
    mapping(address => bool) private _isRegistered;

    constructor() Ownable(msg.sender) {}

    /// @notice Registers a new data source
    /// @param source Address of the off-chain data source
    /// @param venueId Independent venue identifier
    function registerSource(address source, uint8 venueId) external override onlyOwner {
        if (source == address(0)) revert InvalidAddress(source);
        if (_isRegistered[source]) revert SourceAlreadyRegistered(source);

        sources[source] = SourceData({
            source: source,
            reputation: DEFAULT_REPUTATION,
            lastUpdateTime: 0,
            totalReports: 0,
            venueId: venueId,
            active: true
        });
        _isRegistered[source] = true;
        sourceList.push(source);

        emit SourceRegistered(source, venueId);
    }

    /// @notice Records a price submission from a source
    /// @param source Address of the reporting source
    /// @param price The submitted price (scaled 1e18)
    function reportPrice(address source, uint256 price) external override onlyOwner {
        if (!_isRegistered[source]) revert SourceNotRegistered(source);
        if (price == 0) revert InvalidPrice(price);

        lastReportedPrice[source] = price;
        sources[source].lastUpdateTime = block.timestamp;
        sources[source].totalReports += 1;

        emit PriceReported(source, price, block.timestamp);
    }

    /// @notice Updates a source's reputation based on accuracy
    /// @param source Address of the source
    /// @param resolvedPrice Ground-truth price
    function updateReputation(address source, uint256 resolvedPrice) external override onlyOwner {
        if (!_isRegistered[source]) revert SourceNotRegistered(source);
        if (resolvedPrice == 0) revert InvalidPrice(resolvedPrice);

        uint256 reported = lastReportedPrice[source];
        uint256 diff = reported > resolvedPrice ? reported - resolvedPrice : resolvedPrice - reported;
        uint256 errorRatio = (diff * 1e18) / resolvedPrice;

        uint256 accuracy = 1e18;
        if (errorRatio < 1e18) {
            accuracy = 1e18 - errorRatio;
        } else {
            accuracy = 0;
        }

        uint256 oldRep = sources[source].reputation;
        
        // newRep = (1e18 - ALPHA) * oldRep / 1e18 + ALPHA * accuracy / 1e18
        uint256 newRep = ((1e18 - reputationAlpha) * oldRep) / 1e18 + (reputationAlpha * accuracy) / 1e18;

        if (newRep < minReputation) {
            newRep = minReputation;
        } else if (newRep > 1e18) {
            newRep = 1e18;
        }

        sources[source].reputation = newRep;
        emit ReputationUpdated(source, oldRep, newRep);
    }

    /// @notice Reduces reputation for sources that miss rounds
    /// @param source Address of the source
    function applyDecay(address source) external onlyOwner {
        if (!_isRegistered[source]) revert SourceNotRegistered(source);

        uint256 oldRep = sources[source].reputation;
        uint256 newRep = oldRep;
        
        if (oldRep >= DECAY_RATE + minReputation) {
            newRep = oldRep - DECAY_RATE;
        } else {
            newRep = minReputation;
        }

        sources[source].reputation = newRep;
        emit ReputationUpdated(source, oldRep, newRep);
    }

    /// @notice Deactivates a source
    /// @param source Address of the source
    function deactivateSource(address source) external onlyOwner {
        if (!_isRegistered[source]) revert SourceNotRegistered(source);
        sources[source].active = false;
        emit SourceDeactivated(source, "Manually deactivated");
    }

    /// @notice Reactivates a source
    /// @param source Address of the source
    function reactivateSource(address source) external onlyOwner {
        if (!_isRegistered[source]) revert SourceNotRegistered(source);
        sources[source].active = true;
        emit SourceReactivated(source);
    }

    /// @notice Returns the reputation score for a source
    /// @param source Address of the source
    /// @return reputation The current reputation
    function getReputation(address source) external view override returns (uint256) {
        return sources[source].reputation;
    }

    /// @notice Returns whether a source is active and meets min reputation
    /// @param source Address of the source
    /// @return True if active and reputation >= minReputation
    function isActive(address source) external view override returns (bool) {
        if (!_isRegistered[source]) return false;
        return sources[source].active && sources[source].reputation >= minReputation;
    }

    /// @notice Returns the full SourceData struct for a source
    /// @param source Address of the source
    /// @return data Complete SourceData
    function getSourceData(address source) external view override returns (SourceData memory data) {
        return sources[source];
    }

    /// @notice Returns the list of all registered source addresses
    /// @return Array of source addresses
    function getSourceList() external view returns (address[] memory) {
        return sourceList;
    }

    /// @notice Sets the staleness threshold
    /// @param _stalenessThreshold New threshold in seconds
    function setStalenessThreshold(uint256 _stalenessThreshold) external onlyOwner {
        stalenessThreshold = _stalenessThreshold;
    }

    /// @notice Sets the minimum reputation score
    /// @param _minReputation New minimum reputation (1e18 scaled)
    function setMinReputation(uint256 _minReputation) external onlyOwner {
        minReputation = _minReputation;
    }

    /// @notice Sets the reputation EMA alpha
    /// @param _reputationAlpha New alpha value (1e18 scaled)
    function setReputationAlpha(uint256 _reputationAlpha) external onlyOwner {
        reputationAlpha = _reputationAlpha;
    }
}
