// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IResolvedPrice} from "./interfaces/IResolvedPrice.sol";
import {SoftCapController} from "./layer2/SoftCapController.sol";
import {DisputeModule} from "./layer3/DisputeModule.sol";
import {MockOSM} from "./mocks/MockOSM.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Adapter
/// @notice Adapts RWJO v4 layers to Vat/Spot.
/// @dev Reads DisputeModule when a Tier 2 dispute is active,
///      reads SoftCapController when a Tier 1 soft-cap is active,
///      otherwise reads raw OSM unchanged.
///      Vat and Spot require zero modification.
contract Adapter is IResolvedPrice, Ownable {
    MockOSM public osm;
    SoftCapController public softCapController;
    DisputeModule public disputeModule;

    event DataSourceSwitched(string source, uint256 price);

    constructor(
        address _osm,
        address _softCapController,
        address _disputeModule
    ) Ownable(msg.sender) {
        osm = MockOSM(_osm);
        softCapController = SoftCapController(_softCapController);
        disputeModule = DisputeModule(_disputeModule);
    }

    function setOSM(address _osm) external onlyOwner {
        osm = MockOSM(_osm);
    }

    function setSoftCapController(address _softCapController) external onlyOwner {
        softCapController = SoftCapController(_softCapController);
    }

    function setDisputeModule(address _disputeModule) external onlyOwner {
        disputeModule = DisputeModule(_disputeModule);
    }

    /// @notice Read the active system price according to RWJO v4 hierarchy
    /// @return price The resolved price (scaled 1e18)
    /// @return disputed Whether a Tier 2 dispute is active
    function read() external view override returns (uint256 price, bool disputed) {
        // 1. Check if Tier 2 dispute is currently active or recently resolved
        (uint256 disputePrice, bool isDisputed) = disputeModule.read();
        if (isDisputed) {
            return (disputePrice, true);
        }

        // If a dispute was resolved and has a confirmed price, check if disputeModule has priority
        // Or if SoftCap is active in Tier 1
        if (address(softCapController) != address(0) && softCapController.isSoftCapActive()) {
            return (softCapController.lastConfirmedPrice(), false);
        }

        // If DisputeModule has a resolved price from Tier 2 that hasn't made it to OSM yet
        if (disputePrice > 0 && disputeModule.currentDisputeId() > 0) {
            // Can return disputePrice if OSM is paused or stale
        }

        // Default: Read raw OSM price unchanged
        (uint256 osmPrice, ) = osm.read();
        return (osmPrice, false);
    }
}
