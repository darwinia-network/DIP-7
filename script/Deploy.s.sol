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
    address deposit = 0x7FAcDaFB282028E4B3264fB08cd633A9142514df;
    address gRING = 0x87BD07263D0Ed5687407B80FEB16F2E32C2BA44f;
    address hub = 0x279a1aaDb6eC9d213350f95C3Da1A9580FB3326B;

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
