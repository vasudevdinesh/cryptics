// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SourceRegistry} from "./SourceRegistry.sol";
import {ISourceRegistry} from "../interfaces/ISourceRegistry.sol";

/// @title DiversityCheck
/// @notice Enforces minimum independent-venue quorum for a set of sources.
contract DiversityCheck is Ownable {
    SourceRegistry public sourceRegistry;
    uint256 public minIndependentVenues = 3;

    constructor(address _sourceRegistry) Ownable(msg.sender) {
        sourceRegistry = SourceRegistry(_sourceRegistry);
    }

    /// @notice Checks if the provided sources meet the venue diversity quorum.
    /// @param sources Array of source addresses to check.
    /// @return meetsQuorum True if the unique venue count meets the minimum required.
    /// @return uniqueVenueCount The number of unique venues among the sources.
    function checkDiversity(address[] calldata sources) external view returns (bool meetsQuorum, uint256 uniqueVenueCount) {
        uint256 n = sources.length;
        if (n == 0) {
            return (false, 0);
        }

        uint8[] memory seenVenues = new uint8[](n);
        uint256 uniqueCount = 0;

        for (uint256 i = 0; i < n; i++) {
            ISourceRegistry.SourceData memory data = sourceRegistry.getSourceData(sources[i]);
            uint8 venueId = data.venueId;
            
            bool seen = false;
            for (uint256 j = 0; j < uniqueCount; j++) {
                if (seenVenues[j] == venueId) {
                    seen = true;
                    break;
                }
            }

            if (!seen) {
                seenVenues[uniqueCount] = venueId;
                uniqueCount++;
            }
        }

        meetsQuorum = (uniqueCount >= minIndependentVenues);
        uniqueVenueCount = uniqueCount;
    }

    /// @notice Sets the minimum independent venues required for quorum.
    /// @param min The new minimum number of independent venues.
    function setMinIndependentVenues(uint256 min) external onlyOwner {
        minIndependentVenues = min;
    }
}
