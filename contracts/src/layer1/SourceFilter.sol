// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SourceRegistry} from "./SourceRegistry.sol";
import {ISourceRegistry} from "../interfaces/ISourceRegistry.sol";

/// @title SourceFilter
/// @notice Filters and aggregates prices based on reputation, staleness, and outlier detection.
contract SourceFilter is Ownable {
    SourceRegistry public sourceRegistry;
    
    uint256 public outlierThreshold = 0.05e18; // 5%
    uint256 public minReputation = 0.3e18;

    struct PriceSubmission {
        address source;
        uint256 price;
    }

    event SourceExcluded(address indexed source, string reason);

    constructor(address _sourceRegistry) Ownable(msg.sender) {
        sourceRegistry = SourceRegistry(_sourceRegistry);
    }

    /// @notice Filters and aggregates a set of price submissions
    /// @param submissions Array of price submissions
    /// @return weightedMedian The final aggregated weighted median price
    /// @return validSourceCount Number of valid sources included in the final calculation
    /// @return excludedSources Array of source addresses that were excluded
    function filterAndAggregate(PriceSubmission[] calldata submissions) 
        external 
        returns (uint256 weightedMedian, uint256 validSourceCount, address[] memory excludedSources) 
    {
        uint256 n = submissions.length;
        address[] memory tempExcluded = new address[](n);
        uint256 excludedCount = 0;
        
        PriceSubmission[] memory filtered = new PriceSubmission[](n);
        uint256 filteredCount = 0;

        uint256 stalenessThreshold = sourceRegistry.stalenessThreshold();

        // 1 & 2: Filter by reputation and staleness
        for (uint256 i = 0; i < n; i++) {
            address src = submissions[i].source;
            ISourceRegistry.SourceData memory data = sourceRegistry.getSourceData(src);

            if (data.reputation < minReputation) {
                tempExcluded[excludedCount++] = src;
                emit SourceExcluded(src, "Low reputation");
                continue;
            }

            if (block.timestamp > data.lastUpdateTime + stalenessThreshold) {
                tempExcluded[excludedCount++] = src;
                emit SourceExcluded(src, "Stale price");
                continue;
            }

            filtered[filteredCount++] = submissions[i];
        }

        if (filteredCount == 0) {
            excludedSources = new address[](excludedCount);
            for (uint256 i = 0; i < excludedCount; i++) excludedSources[i] = tempExcluded[i];
            return (0, 0, excludedSources);
        }

        // 3. Compute preliminary (unweighted) median
        uint256[] memory preliminaryPrices = new uint256[](filteredCount);
        for (uint256 i = 0; i < filteredCount; i++) {
            preliminaryPrices[i] = filtered[filteredCount - 1 - i].price; // just extracting prices
            preliminaryPrices[i] = filtered[i].price;
        }
        
        uint256 preliminaryMedian = _computeMedian(preliminaryPrices);

        // 4. Filter outliers
        PriceSubmission[] memory validSubmissions = new PriceSubmission[](filteredCount);
        validSourceCount = 0;

        for (uint256 i = 0; i < filteredCount; i++) {
            address src = filtered[i].source;
            uint256 p = filtered[i].price;
            
            uint256 diff = _absDiff(p, preliminaryMedian);
            uint256 deviation = (diff * 1e18) / preliminaryMedian;
            
            if (deviation > outlierThreshold) {
                tempExcluded[excludedCount++] = src;
                emit SourceExcluded(src, "Outlier");
            } else {
                validSubmissions[validSourceCount++] = filtered[i];
            }
        }

        excludedSources = new address[](excludedCount);
        for (uint256 i = 0; i < excludedCount; i++) {
            excludedSources[i] = tempExcluded[i];
        }

        if (validSourceCount == 0) {
            return (0, 0, excludedSources);
        }

        // 5. Compute weighted median
        uint256[] memory finalPrices = new uint256[](validSourceCount);
        uint256[] memory finalWeights = new uint256[](validSourceCount);

        for (uint256 i = 0; i < validSourceCount; i++) {
            finalPrices[i] = validSubmissions[i].price;
            finalWeights[i] = sourceRegistry.getReputation(validSubmissions[i].source);
        }

        weightedMedian = _computeWeightedMedian(finalPrices, finalWeights);

        return (weightedMedian, validSourceCount, excludedSources);
    }

    function _computeMedian(uint256[] memory prices) internal pure returns (uint256) {
        _sort(prices);
        uint256 n = prices.length;
        if (n % 2 == 1) {
            return prices[n / 2];
        } else {
            return (prices[n / 2 - 1] + prices[n / 2]) / 2;
        }
    }

    function _computeWeightedMedian(uint256[] memory prices, uint256[] memory weights) internal pure returns (uint256) {
        uint256 n = prices.length;
        
        // Sort prices and weights together based on prices
        for (uint256 i = 1; i < n; i++) {
            uint256 keyPrice = prices[i];
            uint256 keyWeight = weights[i];
            uint256 j = i;
            while (j > 0 && prices[j - 1] > keyPrice) {
                prices[j] = prices[j - 1];
                weights[j] = weights[j - 1];
                j--;
            }
            prices[j] = keyPrice;
            weights[j] = keyWeight;
        }

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < n; i++) {
            totalWeight += weights[i];
        }

        uint256 halfWeight = totalWeight / 2;
        uint256 accumulatedWeight = 0;

        for (uint256 i = 0; i < n; i++) {
            accumulatedWeight += weights[i];
            if (accumulatedWeight >= halfWeight) {
                return prices[i];
            }
        }
        
        return prices[n - 1];
    }

    function _sort(uint256[] memory arr) internal pure {
        uint256 n = arr.length;
        for (uint256 i = 1; i < n; i++) {
            uint256 key = arr[i];
            uint256 j = i;
            while (j > 0 && arr[j - 1] > key) {
                arr[j] = arr[j - 1];
                j--;
            }
            arr[j] = key;
        }
    }

    function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /// @notice Sets the outlier threshold
    /// @param _outlierThreshold New threshold (1e18 scaled)
    function setOutlierThreshold(uint256 _outlierThreshold) external onlyOwner {
        outlierThreshold = _outlierThreshold;
    }

    /// @notice Sets the minimum reputation score
    /// @param _minReputation New minimum reputation (1e18 scaled)
    function setMinReputation(uint256 _minReputation) external onlyOwner {
        minReputation = _minReputation;
    }
}
