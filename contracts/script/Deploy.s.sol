// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
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

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // 1. Layer 1
        SourceRegistry sourceRegistry = new SourceRegistry();
        SourceFilter sourceFilter = new SourceFilter(address(sourceRegistry));
        DiversityCheck diversityCheck = new DiversityCheck(address(sourceRegistry));

        // 2. Layer 2
        TierClassifier tierClassifier = new TierClassifier();
        SoftCapController softCapController = new SoftCapController();
        JurorRegistry jurorRegistry = new JurorRegistry();
        SpotCheckPanel spotCheckPanel = new SpotCheckPanel(address(jurorRegistry));

        // 3. Layer 3
        MockVRFCoordinator vrfCoordinator = new MockVRFCoordinator(42);
        RandomSelector randomSelector = new RandomSelector(address(jurorRegistry), address(vrfCoordinator));
        DeviationCap deviationCap = new DeviationCap();
        HoneypotInjector honeypotInjector = new HoneypotInjector();

        DisputeModule disputeModule = new DisputeModule(
            address(jurorRegistry),
            address(randomSelector),
            address(deviationCap),
            address(honeypotInjector)
        );

        jurorRegistry.setDisputeModule(address(disputeModule));
        randomSelector.setDisputeModule(address(disputeModule));
        honeypotInjector.setDisputeModule(address(disputeModule));

        // 4. Mocks & Adapter
        MockOSM osm = new MockOSM(100e18, 3600);
        Adapter adapter = new Adapter(address(osm), address(softCapController), address(disputeModule));

        vm.stopBroadcast();
    }
}
