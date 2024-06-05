// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {CollatorStakingHub} from "../src/collator/CollatorStakingHub.sol";
import {Deposit} from "../src/deposit/Deposit.sol";
import {RingTimelockController} from "../src/governance/RingTimelockController.sol";
import {GovernanceRing} from "../src/governance/GovernanceRing.sol";
import {RingDAO, IVotes, TimelockControllerUpgradeable} from "../src/governance/RingDAO.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // RingDAO-multisig
        address multisig = 0x040f331774Ed6BB161412B4cEDb1358B382aF3A5;

        address deposit = Upgrades.deployTransparentProxy(
            "Deposit.sol:Deposit", multisig, abi.encodeCall(Deposit.initialize, ("RING Deposit NFT", "RDPS"))
        );

        Options memory hubOpts;
        hubOpts.constructorData = abi.encode(deposit, "RING");
        address hub = Upgrades.deployTransparentProxy(
            "CollatorStakingHub.sol:CollatorStakingHub",
            multisig,
            abi.encodeCall(CollatorStakingHub.initialize, ()),
            hubOpts
        );

        uint256 minDelay = 3 days;
        address timelock = Upgrades.deployTransparentProxy(
            "RingTimelockController.sol:RingTimelockController",
            multisig,
            abi.encodeCall(RingTimelockController.initialize, (minDelay, new address[](0), new address[](0), multisig))
        );

        address gRING = Upgrades.deployTransparentProxy(
            "GovernanceRing.sol:GovernanceRing",
            timelock,
            abi.encodeCall(GovernanceRing.initialize, ("Governance RING", "gRING"))
        );

        Options memory daoOpts;
        daoOpts.constructorData = abi.encode(deposit, hub);
        address ringDAO = Upgrades.deployTransparentProxy(
            "RingDAO.sol:RingDAO",
            timelock,
            abi.encodeCall(
                RingDAO.initialize, (IVotes(gRING), TimelockControllerUpgradeable(payable(timelock)), "RingDAO")
            )
        );
        // RingTimelockController(timelock).granRole(RingTimelockController(timelock).PROPOSER_ROLE, ringDAO);

        vm.stopBroadcast();
    }
}
