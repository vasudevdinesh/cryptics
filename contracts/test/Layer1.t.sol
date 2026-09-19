// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SourceRegistry} from "../src/layer1/SourceRegistry.sol";
import {SourceFilter} from "../src/layer1/SourceFilter.sol";
import {DiversityCheck} from "../src/layer1/DiversityCheck.sol";
import {ISourceRegistry} from "../src/interfaces/ISourceRegistry.sol";

contract Layer1Test is Test {
    SourceRegistry public registry;
    SourceFilter public filter;
    DiversityCheck public diversity;

    address public source1 = address(0x101);
    address public source2 = address(0x102);
    address public source3 = address(0x103);
    address public outlierSource = address(0x104);
    address public staleSource = address(0x105);

    function setUp() public {
        registry = new SourceRegistry();
        filter = new SourceFilter(address(registry));
        diversity = new DiversityCheck(address(registry));

        // Register sources with different venues
        registry.registerSource(source1, 1);
        registry.registerSource(source2, 2);
        registry.registerSource(source3, 3);
        registry.registerSource(outlierSource, 4);
        registry.registerSource(staleSource, 5);

        // Report normal prices for healthy sources
        registry.reportPrice(source1, 100e18);
        registry.reportPrice(source2, 101e18);
        registry.reportPrice(source3, 100e18);
        registry.reportPrice(outlierSource, 150e18); // Large outlier
        registry.reportPrice(staleSource, 100e18);
    }

    function testSourceRegistration() public view {
        ISourceRegistry.SourceData memory data = registry.getSourceData(source1);
        assertEq(data.venueId, 1);
        assertEq(data.reputation, 0.5e18); // Default reputation
        assertTrue(data.active);
    }

    function testDiversityCheck() public view {
        address[] memory sources = new address[](3);
        sources[0] = source1;
        sources[1] = source2;
        sources[2] = source3;

        (bool meetsQuorum, uint256 count) = diversity.checkDiversity(sources);
        assertTrue(meetsQuorum);
        assertEq(count, 3);
    }

    function testDiversityCheckFailsWithSameVenue() public {
        address sourceDup = address(0x106);
        registry.registerSource(sourceDup, 1); // Same venue as source1

        address[] memory sources = new address[](2);
        sources[0] = source1;
        sources[1] = sourceDup;

        (bool meetsQuorum, uint256 count) = diversity.checkDiversity(sources);
        assertFalse(meetsQuorum);
        assertEq(count, 1);
    }

    function testOutlierExclusion() public {
        SourceFilter.PriceSubmission[] memory subs = new SourceFilter.PriceSubmission[](4);
        subs[0] = SourceFilter.PriceSubmission({source: source1, price: 100e18});
        subs[1] = SourceFilter.PriceSubmission({source: source2, price: 101e18});
        subs[2] = SourceFilter.PriceSubmission({source: source3, price: 100e18});
        subs[3] = SourceFilter.PriceSubmission({source: outlierSource, price: 150e18});

        (uint256 median, uint256 validCount, address[] memory excluded) = filter.filterAndAggregate(subs);
        assertEq(validCount, 3);
        assertEq(excluded.length, 1);
        assertEq(excluded[0], outlierSource);
        assertApproxEqAbs(median, 100e18, 1e18);
    }

    function testStalenessExclusion() public {
        // Warp time forward by 2 hours to make staleSource stale
        vm.warp(block.timestamp + 7200);

        // Update sources 1, 2, 3 now, but leave staleSource untouched
        registry.reportPrice(source1, 100e18);
        registry.reportPrice(source2, 101e18);
        registry.reportPrice(source3, 100e18);

        SourceFilter.PriceSubmission[] memory subs = new SourceFilter.PriceSubmission[](4);
        subs[0] = SourceFilter.PriceSubmission({source: source1, price: 100e18});
        subs[1] = SourceFilter.PriceSubmission({source: source2, price: 101e18});
        subs[2] = SourceFilter.PriceSubmission({source: source3, price: 100e18});
        subs[3] = SourceFilter.PriceSubmission({source: staleSource, price: 100e18});

        (uint256 median, uint256 validCount, address[] memory excluded) = filter.filterAndAggregate(subs);
        assertEq(validCount, 3);
        assertEq(excluded.length, 1);
        assertEq(excluded[0], staleSource);
        assertApproxEqAbs(median, 100e18, 1e18);
    }

    function testReputationUpdate() public {
        uint256 oldRep = registry.getReputation(source1);
        // Source reported 100e18, resolved is 100e18 -> high accuracy
        registry.updateReputation(source1, 100e18);
        uint256 newRep = registry.getReputation(source1);
        assertTrue(newRep >= oldRep);
    }
}
