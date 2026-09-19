// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {JurorRegistry} from "../src/layer3/JurorRegistry.sol";
import {RandomSelector} from "../src/layer3/RandomSelector.sol";
import {DisputeModule} from "../src/layer3/DisputeModule.sol";
import {HoneypotInjector} from "../src/layer3/HoneypotInjector.sol";
import {DeviationCap} from "../src/layer3/DeviationCap.sol";
import {MockVRFCoordinator} from "../src/mocks/MockVRFCoordinator.sol";

contract Layer3Test is Test {
    JurorRegistry public jurorRegistry;
    MockVRFCoordinator public vrf;
    RandomSelector public selector;
    DeviationCap public devCap;
    HoneypotInjector public honeypot;
    DisputeModule public disputeModule;

    address public j1 = address(0x301);
    address public j2 = address(0x302);
    address public j3 = address(0x303);
    address public j4 = address(0x304);
    address public j5 = address(0x305);

    function setUp() public {
        jurorRegistry = new JurorRegistry();
        vrf = new MockVRFCoordinator(12345);
        selector = new RandomSelector(address(jurorRegistry), address(vrf));
        devCap = new DeviationCap();
        honeypot = new HoneypotInjector();
        
        disputeModule = new DisputeModule(
            address(jurorRegistry),
            address(selector),
            address(devCap),
            address(honeypot)
        );

        jurorRegistry.setDisputeModule(address(disputeModule));
        selector.setDisputeModule(address(disputeModule));
        honeypot.setDisputeModule(address(disputeModule));

        // Register 5 jurors
        address[5] memory list = [j1, j2, j3, j4, j5];
        for (uint256 i = 0; i < 5; i++) {
            vm.deal(list[i], 1 ether);
            vm.prank(list[i]);
            jurorRegistry.register{value: 0.1 ether}();
        }
    }

    function testJurorBondAndRegistration() public view {
        assertTrue(jurorRegistry.isEligible(j1));
        assertEq(jurorRegistry.getJurorData(j1).bondAmount, 0.1 ether);
        assertEq(jurorRegistry.getEffectiveWeight(j1), 0.1e18); // Base weight
    }

    function testDeviationCapClamping() public {
        // Last confirmed 100, candidate 125, maxDeviation 15% -> clamped to 115
        (uint256 clamped, bool wasClamped) = devCap.clamp(125e18, 100e18);
        assertTrue(wasClamped);
        assertEq(clamped, 115e18);

        // Within limit (110 <= 115)
        (uint256 notClamped, bool wasClamped2) = devCap.clamp(110e18, 100e18);
        assertFalse(wasClamped2);
        assertEq(notClamped, 110e18);
    }

    function testHoneypotEvaluation() public {
        uint256 truePrice = 100e18;
        bytes32 salt = keccak256("demo_salt");
        bytes32 trueHash = keccak256(abi.encodePacked(truePrice, salt));

        honeypot.injectHoneypot(1, trueHash);
        honeypot.revealHoneypot(1, truePrice, salt);

        // Honest juror price 101e18 (1% deviation, within 5% tolerance)
        (bool passedHonest, ) = honeypot.evaluateJuror(1, 101e18);
        assertTrue(passedHonest);

        // Lying juror price 120e18 (20% deviation, fails tolerance)
        (bool passedLiar, ) = honeypot.evaluateJuror(1, 120e18);
        assertFalse(passedLiar);
    }
}
