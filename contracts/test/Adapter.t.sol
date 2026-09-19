// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Adapter} from "../src/Adapter.sol";
import {MockOSM} from "../src/mocks/MockOSM.sol";
import {SoftCapController} from "../src/layer2/SoftCapController.sol";
import {DisputeModule} from "../src/layer3/DisputeModule.sol";
import {JurorRegistry} from "../src/layer3/JurorRegistry.sol";
import {RandomSelector} from "../src/layer3/RandomSelector.sol";
import {DeviationCap} from "../src/layer3/DeviationCap.sol";
import {HoneypotInjector} from "../src/layer3/HoneypotInjector.sol";
import {MockVRFCoordinator} from "../src/mocks/MockVRFCoordinator.sol";

contract AdapterTest is Test {
    MockOSM public osm;
    SoftCapController public softCap;
    DisputeModule public disputeModule;
    Adapter public adapter;

    function setUp() public {
        osm = new MockOSM(100e18, 3600);
        softCap = new SoftCapController();
        
        JurorRegistry jurorRegistry = new JurorRegistry();
        MockVRFCoordinator vrf = new MockVRFCoordinator(12345);
        RandomSelector selector = new RandomSelector(address(jurorRegistry), address(vrf));
        DeviationCap devCap = new DeviationCap();
        HoneypotInjector honeypot = new HoneypotInjector();

        disputeModule = new DisputeModule(
            address(jurorRegistry),
            address(selector),
            address(devCap),
            address(honeypot)
        );

        adapter = new Adapter(address(osm), address(softCap), address(disputeModule));
    }

    function testNormalReadFromOSM() public view {
        // Without active soft-cap or dispute, adapter reads OSM price
        (uint256 price, bool disputed) = adapter.read();
        assertEq(price, 100e18);
        assertFalse(disputed);
    }

    function testReadWhenSoftCapActive() public {
        // Trigger a soft-cap update
        softCap.applySoftCap(115e18, 100e18);
        assertTrue(softCap.isSoftCapActive());

        // Adapter should read the soft-capped price (105e18)
        (uint256 price, bool disputed) = adapter.read();
        assertEq(price, 105e18);
        assertFalse(disputed);
    }
}
