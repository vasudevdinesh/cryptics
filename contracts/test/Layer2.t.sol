// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TierClassifier} from "../src/layer2/TierClassifier.sol";
import {SoftCapController} from "../src/layer2/SoftCapController.sol";
import {SpotCheckPanel} from "../src/layer2/SpotCheckPanel.sol";
import {ITierClassifier} from "../src/interfaces/ITierClassifier.sol";
import {JurorRegistry} from "../src/layer3/JurorRegistry.sol";

contract Layer2Test is Test {
    TierClassifier public classifier;
    SoftCapController public softCap;
    SpotCheckPanel public spotCheck;
    JurorRegistry public jurorRegistry;

    address public juror1 = address(0x201);
    address public juror2 = address(0x202);
    address public juror3 = address(0x203);

    function setUp() public {
        classifier = new TierClassifier();
        softCap = new SoftCapController();
        jurorRegistry = new JurorRegistry();
        spotCheck = new SpotCheckPanel(address(jurorRegistry));

        // Fund and register jurors
        vm.deal(juror1, 1 ether);
        vm.deal(juror2, 1 ether);
        vm.deal(juror3, 1 ether);

        vm.prank(juror1);
        jurorRegistry.register{value: 0.1 ether}();
        vm.prank(juror2);
        jurorRegistry.register{value: 0.1 ether}();
        vm.prank(juror3);
        jurorRegistry.register{value: 0.1 ether}();
    }

    function testTier0NormalClassification() public {
        // 100 to 101 is 1% deviation (< 3% theta1)
        ITierClassifier.Tier tier = classifier.classify(101e18, 100e18);
        assertTrue(tier == ITierClassifier.Tier.NORMAL);
    }

    function testTier1ModerateClassification() public {
        // 100 to 105 is 5% deviation (>= 3% and < 10%)
        ITierClassifier.Tier tier = classifier.classify(105e18, 100e18);
        assertTrue(tier == ITierClassifier.Tier.MODERATE);
    }

    function testTier2CriticalClassification() public {
        // 100 to 115 is 15% deviation (>= 10%)
        ITierClassifier.Tier tier = classifier.classify(115e18, 100e18);
        assertTrue(tier == ITierClassifier.Tier.CRITICAL);
    }

    function testSoftCapClamping() public {
        // Max rate of change is 5%. If current = 100 and candidate = 108:
        // Capped price should be 105.
        (uint256 cappedPrice, bool wasCapped) = softCap.applySoftCap(108e18, 100e18);
        assertTrue(wasCapped);
        assertEq(cappedPrice, 105e18);
        assertTrue(softCap.isSoftCapActive());
    }

    function testSoftCapNoClampingUnderLimit() public {
        // Move is 2% (< 5% max)
        (uint256 cappedPrice, bool wasCapped) = softCap.applySoftCap(102e18, 100e18);
        assertFalse(wasCapped);
        assertEq(cappedPrice, 102e18);
        assertFalse(softCap.isSoftCapActive());
    }

    function testSpotCheckPanelApproval() public {
        address[] memory jurors = new address[](3);
        jurors[0] = juror1;
        jurors[1] = juror2;
        jurors[2] = juror3;

        uint256 checkId = spotCheck.initiateSpotCheck(1, 104e18, jurors);

        // Juror 1 and Juror 2 vote approve
        vm.prank(juror1);
        spotCheck.vote(checkId, true);
        vm.prank(juror2);
        spotCheck.vote(checkId, true);

        SpotCheckPanel.SpotCheckStatus status = spotCheck.getSpotCheckStatus(checkId);
        assertTrue(status == SpotCheckPanel.SpotCheckStatus.Approved);
    }
}
