// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SourceRegistry} from "../src/layer1/SourceRegistry.sol";
import {SourceFilter} from "../src/layer1/SourceFilter.sol";
import {DiversityCheck} from "../src/layer1/DiversityCheck.sol";
import {TierClassifier} from "../src/layer2/TierClassifier.sol";
import {SoftCapController} from "../src/layer2/SoftCapController.sol";
import {SpotCheckPanel} from "../src/layer2/SpotCheckPanel.sol";
import {JurorRegistry} from "../src/layer3/JurorRegistry.sol";
import {RandomSelector} from "../src/layer3/RandomSelector.sol";
import {DisputeModule} from "../src/layer3/DisputeModule.sol";
import {HoneypotInjector} from "../src/layer3/HoneypotInjector.sol";
import {DeviationCap} from "../src/layer3/DeviationCap.sol";
import {Adapter} from "../src/Adapter.sol";
import {MockOSM} from "../src/mocks/MockOSM.sol";
import {MockVRFCoordinator} from "../src/mocks/MockVRFCoordinator.sol";
import {ITierClassifier} from "../src/interfaces/ITierClassifier.sol";

contract IntegrationTest is Test {
    // Layer 1
    SourceRegistry public sourceRegistry;
    SourceFilter public sourceFilter;
    DiversityCheck public diversityCheck;

    // Layer 2
    TierClassifier public classifier;
    SoftCapController public softCap;
    SpotCheckPanel public spotCheck;

    // Layer 3
    JurorRegistry public jurorRegistry;
    MockVRFCoordinator public vrf;
    RandomSelector public randomSelector;
    DisputeModule public disputeModule;
    HoneypotInjector public honeypot;
    DeviationCap public deviationCap;

    // Bridge & Mocks
    MockOSM public osm;
    Adapter public adapter;

    // Actors
    address public s1 = address(0x11);
    address public s2 = address(0x12);
    address public s3 = address(0x13);
    address public s_stale = address(0x14);
    address public s_outlier = address(0x15);

    address public j_honest1 = address(0x21);
    address public j_honest2 = address(0x22);
    address public j_honest3 = address(0x23);
    address public j_honest4 = address(0x24);
    address public j_liar = address(0x25);

    function setUp() public {
        // Deploy L1
        sourceRegistry = new SourceRegistry();
        sourceFilter = new SourceFilter(address(sourceRegistry));
        diversityCheck = new DiversityCheck(address(sourceRegistry));

        // Deploy L2
        classifier = new TierClassifier();
        softCap = new SoftCapController();
        jurorRegistry = new JurorRegistry();
        spotCheck = new SpotCheckPanel(address(jurorRegistry));

        // Deploy L3
        vrf = new MockVRFCoordinator(777);
        randomSelector = new RandomSelector(address(jurorRegistry), address(vrf));
        deviationCap = new DeviationCap();
        honeypot = new HoneypotInjector();

        disputeModule = new DisputeModule(
            address(jurorRegistry),
            address(randomSelector),
            address(deviationCap),
            address(honeypot)
        );

        jurorRegistry.setDisputeModule(address(disputeModule));
        randomSelector.setDisputeModule(address(disputeModule));
        honeypot.setDisputeModule(address(disputeModule));

        // Mocks & Adapter
        osm = new MockOSM(100e18, 3600);
        adapter = new Adapter(address(osm), address(softCap), address(disputeModule));

        // Setup 5 sources with distinct venues
        sourceRegistry.registerSource(s1, 1);
        sourceRegistry.registerSource(s2, 2);
        sourceRegistry.registerSource(s3, 3);
        sourceRegistry.registerSource(s_stale, 4);
        sourceRegistry.registerSource(s_outlier, 5);

        // Setup 5 jurors with bonds
        address[5] memory jurors = [j_honest1, j_honest2, j_honest3, j_honest4, j_liar];
        for (uint256 i = 0; i < 5; i++) {
            vm.deal(jurors[i], 1 ether);
            vm.prank(jurors[i]);
            jurorRegistry.register{value: 0.1 ether}();
        }
    }

    /// @notice Round 1: Clean Tier 0 Flow (no intervention, adapter reads OSM)
    function testRound1_CleanTier0() public {
        sourceRegistry.reportPrice(s1, 100e18);
        sourceRegistry.reportPrice(s2, 100.5e18);
        sourceRegistry.reportPrice(s3, 99.8e18);

        SourceFilter.PriceSubmission[] memory subs = new SourceFilter.PriceSubmission[](3);
        subs[0] = SourceFilter.PriceSubmission({source: s1, price: 100e18});
        subs[1] = SourceFilter.PriceSubmission({source: s2, price: 100.5e18});
        subs[2] = SourceFilter.PriceSubmission({source: s3, price: 99.8e18});

        (uint256 median, uint256 count, ) = sourceFilter.filterAndAggregate(subs);
        assertEq(count, 3);

        ITierClassifier.Tier tier = classifier.classify(median, 100e18);
        assertEq(uint256(tier), uint256(ITierClassifier.Tier.NORMAL));

        (uint256 readPrice, bool disputed) = adapter.read();
        assertEq(readPrice, 100e18);
        assertFalse(disputed);
    }

    /// @notice Round 2: Tier 1 - Stale/Outlier filtered upstream, soft-cap holds, no halt
    function testRound2_Tier1_FilteringAndSoftCap() public {
        // Fast-forward so s_stale becomes stale
        vm.warp(block.timestamp + 7200);

        sourceRegistry.reportPrice(s1, 106e18);
        sourceRegistry.reportPrice(s2, 106.2e18);
        sourceRegistry.reportPrice(s3, 105.8e18);
        sourceRegistry.reportPrice(s_outlier, 150e18); // Outlier

        SourceFilter.PriceSubmission[] memory subs = new SourceFilter.PriceSubmission[](5);
        subs[0] = SourceFilter.PriceSubmission({source: s1, price: 106e18});
        subs[1] = SourceFilter.PriceSubmission({source: s2, price: 106.2e18});
        subs[2] = SourceFilter.PriceSubmission({source: s3, price: 105.8e18});
        subs[3] = SourceFilter.PriceSubmission({source: s_stale, price: 100e18}); // Not refreshed
        subs[4] = SourceFilter.PriceSubmission({source: s_outlier, price: 150e18});

        (uint256 median, uint256 count, address[] memory excluded) = sourceFilter.filterAndAggregate(subs);
        assertEq(count, 3);
        assertEq(excluded.length, 2); // Both stale and outlier filtered out!

        // Deviation from 100 to 106 is 6% (Tier 1: 3% <= dev < 10%)
        ITierClassifier.Tier tier = classifier.classify(median, 100e18);
        assertEq(uint256(tier), uint256(ITierClassifier.Tier.MODERATE));

        // Soft-cap controller clamps 6% move to 5%
        (uint256 cappedPrice, bool wasCapped) = softCap.applySoftCap(median, 100e18);
        assertTrue(wasCapped);
        assertEq(cappedPrice, 105e18);

        // Adapter now serves soft-capped price
        (uint256 readPrice, bool disputed) = adapter.read();
        assertEq(readPrice, 105e18);
        assertFalse(disputed);
    }

    /// @notice Round 3: Tier 2 - Halt & Dispute, honeypot catches lying juror who is slashed
    function testRound3_Tier2_HaltAndSlashing() public {
        uint256 manipulatedPrice = 125e18; // 25% deviation -> Tier 2
        ITierClassifier.Tier tier = classifier.classify(manipulatedPrice, 100e18);
        assertEq(uint256(tier), uint256(ITierClassifier.Tier.CRITICAL));

        // Inject Honeypot with known truth = 101e18
        uint256 truePrice = 101e18;
        bytes32 salt = keccak256("honeypot_salt_r3");
        honeypot.injectHoneypot(3, keccak256(abi.encodePacked(truePrice, salt)));

        // Initiate dispute
        disputeModule.initiateDispute(3, manipulatedPrice);
        assertTrue(disputeModule.disputeActive());

        // Fulfill VRF
        vrf.fulfillRandomWords(1);

        // Jurors commit votes
        bytes32 j1Commit = keccak256(abi.encodePacked(uint256(101e18), uint256(101e18), bytes32("salt1")));
        bytes32 jLiarCommit = keccak256(abi.encodePacked(uint256(124e18), uint256(124e18), bytes32("saltLiar")));

        vm.prank(j_honest1);
        disputeModule.commitVote(1, j1Commit);
        vm.prank(j_liar);
        disputeModule.commitVote(1, jLiarCommit);

        // Advance to reveal
        vm.warp(block.timestamp + 301);
        vm.prank(j_honest1);
        disputeModule.revealVote(1, 101e18, 101e18, bytes32("salt1"));
        vm.prank(j_liar);
        disputeModule.revealVote(1, 124e18, 124e18, bytes32("saltLiar"));

        // Reveal honeypot
        honeypot.revealHoneypot(3, truePrice, salt);

        // Resolve dispute
        vm.warp(block.timestamp + 301);
        disputeModule.resolveDispute(1);

        // Verify liar was slashed
        uint256 liarBond = jurorRegistry.getJurorData(j_liar).bondAmount;
        assertTrue(liarBond < 0.1 ether); // Slashed 30%
    }
}
