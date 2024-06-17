// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {safeconsole} from "forge-std/safeconsole.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {CollatorStakingHub} from "../src/collator/CollatorStakingHub.sol";
import {Deposit} from "../src/deposit/Deposit.sol";
import {RingTimelockController} from "../src/governance/RingTimelockController.sol";
import {GovernanceRing} from "../src/governance/GovernanceRing.sol";
import {RingDAO, IVotes, TimelockController} from "../src/governance/RingDAO.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // RingDAO-multisig
        address multisig = 0x040f331774Ed6BB161412B4cEDb1358B382aF3A5;
        safeconsole.log("Multisig: ", multisig);

        address deposit = Upgrades.deployTransparentProxy(
            "Deposit.sol:Deposit", multisig, abi.encodeCall(Deposit.initialize, ("RING Deposit NFT", "RDPS"))
        );
        safeconsole.log("Depoist: ", deposit);
        safeconsole.log("Depoist_Logic: ", Upgrades.getImplementationAddress(deposit));

        uint256 minDelay = 3 days;
        address timelock = Upgrades.deployTransparentProxy(
            "RingTimelockController.sol:RingTimelockController",
            multisig,
            abi.encodeCall(RingTimelockController.initialize, (minDelay, new address[](0), new address[](0), multisig))
        );
        safeconsole.log("Timelock: ", timelock);
        safeconsole.log("Timelock_Logic: ", Upgrades.getImplementationAddress(timelock));

        GovernanceRing gRING = new GovernanceRing(multisig, "Governance RING", "gRING");
        safeconsole.log("gRING: ", address(gRING));

        RingDAO ringDAO = new RingDAO(IVotes(gRING), TimelockController(payable(timelock)), "RingDAO");
        safeconsole.log("RingDAO: ", address(ringDAO));

        address hub = Upgrades.deployTransparentProxy(
            "CollatorStakingHub.sol:CollatorStakingHub",
            timelock,
            abi.encodeCall(CollatorStakingHub.initialize, (address(gRING), deposit))
        );
        safeconsole.log("Hub: ", hub);
        safeconsole.log("Hub_Logic: ", Upgrades.getImplementationAddress(hub));

        // RingTimelockController(timelock).grantRole(RingTimelockController(timelock).PROPOSER_ROLE(), ringDAO);
        // RingTimelockController(gRING).grantRole(GovernanceRing(gRING).MINTER_ROLE(), hub);
        // RingTimelockController(gRING).grantRole(GovernanceRing(gRING).BURNER_ROLE(), hub);

        vm.stopBroadcast();
    }
}
