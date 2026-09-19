// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IJurorRegistry} from "../interfaces/IJurorRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title JurorRegistry
/// @notice Implements juror bonding, unbonding, and reputation tracking.
contract JurorRegistry is IJurorRegistry, Ownable, ReentrancyGuard {
    uint256 public constant MIN_BOND = 0.01 ether;
    uint256 public constant SENIOR_BOND = 0.1 ether;
    uint256 public constant WEIGHT_MIN = 0.1e18;
    uint256 public constant WEIGHT_MAX = 5e18;
    uint256 public constant LAMBDA = 0.15e18;
    uint256 public constant VESTING_WINDOW = 100; // blocks
    uint256 public constant UNBOND_TIMELOCK = 1 days;

    mapping(address => JurorData) private _jurors;
    address[] public jurorList;
    mapping(address => uint256) public unbondRequestTime;
    mapping(address => uint256) public unbondRequestAmount;
    address public disputeModule;

    error InsufficientBond();
    error AlreadyRegistered();
    error NotRegistered();
    error Unauthorized();
    error InvalidAmount();
    error TimelockNotExpired();
    error NoUnbondRequest();
    error TransferFailed();

    modifier onlyDisputeModule() {
        if (msg.sender != disputeModule) revert Unauthorized();
        _;
    }

    constructor() Ownable(msg.sender) {}

    /// @notice Set the dispute module address.
    function setDisputeModule(address _module) external onlyOwner {
        disputeModule = _module;
    }

    /// @notice Register as a juror by bonding ETH.
    function register() external payable override nonReentrant {
        if (msg.value < MIN_BOND) revert InsufficientBond();
        JurorData storage data = _jurors[msg.sender];
        if (data.registered) revert AlreadyRegistered();

        data.juror = msg.sender;
        data.bondAmount = msg.value;
        data.weight = WEIGHT_MIN;
        data.vestedWeight = 0;
        data.unvestedGains = WEIGHT_MIN;
        data.vestingStartBlock = block.number;
        data.registered = true;

        jurorList.push(msg.sender);

        emit JurorRegistered(msg.sender, msg.value);
        emit BondDeposited(msg.sender, msg.value, msg.value);
    }

    /// @notice Add additional bond.
    function bond() external payable override nonReentrant {
        if (msg.value == 0) revert InvalidAmount();
        JurorData storage data = _jurors[msg.sender];
        if (!data.registered) revert NotRegistered();

        data.bondAmount += msg.value;
        emit BondDeposited(msg.sender, msg.value, data.bondAmount);
    }

    /// @notice Withdraw bond (subject to timelock).
    function unbond(uint256 amount) external override {
        JurorData storage data = _jurors[msg.sender];
        if (!data.registered) revert NotRegistered();
        if (amount == 0 || amount > data.bondAmount) revert InvalidAmount();
        if (unbondRequestAmount[msg.sender] > 0) revert InvalidAmount(); // Only one request allowed

        unbondRequestAmount[msg.sender] = amount;
        unbondRequestTime[msg.sender] = block.timestamp;
    }

    /// @notice Claim withdrawn bond after timelock.
    function claimUnbond() external nonReentrant {
        uint256 amount = unbondRequestAmount[msg.sender];
        if (amount == 0) revert NoUnbondRequest();
        if (block.timestamp < unbondRequestTime[msg.sender] + UNBOND_TIMELOCK) revert TimelockNotExpired();

        unbondRequestAmount[msg.sender] = 0;
        unbondRequestTime[msg.sender] = 0;

        JurorData storage data = _jurors[msg.sender];
        data.bondAmount -= amount;

        emit BondWithdrawn(msg.sender, amount, data.bondAmount);
        
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Get the effective weight of a juror.
    function getEffectiveWeight(address juror) public view override returns (uint256) {
        JurorData memory data = _jurors[juror];
        if (!data.registered) return 0;

        uint256 elapsed = block.number > data.vestingStartBlock ? block.number - data.vestingStartBlock : 0;
        if (elapsed > VESTING_WINDOW) elapsed = VESTING_WINDOW;

        uint256 effective = data.vestedWeight + (data.unvestedGains * elapsed) / VESTING_WINDOW;
        if (effective < WEIGHT_MIN) return WEIGHT_MIN;
        if (effective > WEIGHT_MAX) return WEIGHT_MAX;
        return effective;
    }

    /// @notice Update a juror's weight after a round.
    function updateWeight(address juror, uint256 roundScore) external override onlyDisputeModule {
        JurorData storage data = _jurors[juror];
        if (!data.registered) return;

        data.totalDisputes++;
        data.lastActiveRound = block.number;

        uint256 oldWeight = getEffectiveWeight(juror);
        uint256 newWeight = ((1e18 - LAMBDA) * oldWeight) / 1e18 + (LAMBDA * roundScore) / 1e18;

        if (newWeight > oldWeight) {
            data.vestedWeight = oldWeight;
            data.unvestedGains = newWeight - oldWeight;
            data.vestingStartBlock = block.number;
        } else {
            data.vestedWeight = newWeight;
            data.unvestedGains = 0;
            data.vestingStartBlock = block.number;
        }
        
        data.weight = newWeight;

        emit WeightUpdated(juror, oldWeight, newWeight);
    }

    /// @notice Slash a juror's bond.
    function slash(address juror, uint256 amount) external override onlyDisputeModule {
        JurorData storage data = _jurors[juror];
        if (!data.registered) return;

        uint256 slashAmount = amount > data.bondAmount ? data.bondAmount : amount;
        data.bondAmount -= slashAmount;
        
        emit JurorSlashed(juror, slashAmount, data.bondAmount);
    }

    /// @notice Check if a juror is eligible.
    function isEligible(address juror) external view override returns (bool) {
        JurorData memory data = _jurors[juror];
        return data.registered && data.bondAmount >= MIN_BOND;
    }

    /// @notice Get full juror data.
    function getJurorData(address juror) external view override returns (JurorData memory) {
        return _jurors[juror];
    }

    /// @notice Get all registered jurors.
    function getJurors() external view override returns (address[] memory) {
        return jurorList;
    }
}
