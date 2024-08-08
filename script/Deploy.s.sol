// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {safeconsole} from "forge-std/safeconsole.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {CollatorStakingHub} from "../src/collator/CollatorStakingHub.sol";
import {Deposit} from "../src/deposit/Deposit.sol";
import {GovernanceRing} from "../src/governance/GovernanceRing.sol";

contract DeployScript is Script {
    address deployer = 0x0f14341A7f464320319025540E8Fe48Ad0fe5aec;
    address deposit = 0x74aA3559BBBB1C4D1395024f105A3309247D4419;
    address gRING = 0xF6ffE57fB0580A0B3cC76BD6aEd579463201a8a1;
    address hub = 0x4B2cB0F18DEF041940Ec78C71DA1B73F2d984254;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        require(msg.sender == deployer, "!deployer");

        address deposit_PROXY = Upgrades.deployTransparentProxy(
            "Deposit.sol:Deposit", deployer, abi.encodeCall(Deposit.initialize, ("RING Deposit NFT", "RDPS"))
        );
        safeconsole.log("Depoist: ", deposit_PROXY);
        safeconsole.log("Depoist_Logic: ", Upgrades.getImplementationAddress(deposit_PROXY));

        address gRING_PROXY = Upgrades.deployTransparentProxy(
            "GovernanceRing.sol:GovernanceRing",
            deployer,
            abi.encodeCall(GovernanceRing.initialize, (deployer, hub, deposit, "Governance RING", "gRING"))
        );
        safeconsole.log("gRING: ", gRING_PROXY);
        safeconsole.log("gRING_Logic: ", Upgrades.getImplementationAddress(gRING_PROXY));

        address hub_PROXY = Upgrades.deployTransparentProxy(
            "CollatorStakingHub.sol:CollatorStakingHub",
            deployer,
            abi.encodeCall(CollatorStakingHub.initialize, (gRING, deposit))
        );
        safeconsole.log("Hub: ", hub_PROXY);
        safeconsole.log("Hub_Logic: ", Upgrades.getImplementationAddress(hub_PROXY));

        vm.stopBroadcast();
    }
}
