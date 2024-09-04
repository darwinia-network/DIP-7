// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {safeconsole} from "forge-std/safeconsole.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Core} from "openzeppelin-foundry-upgrades/internal/Core.sol";

import {CollatorStakingHub} from "../src/collator/CollatorStakingHub.sol";

contract MigrateScript is Script {
    address hub = 0xb037E75fE2BFA42DdDC17BB90963Dafe10A5Dd11;

    function run() public {
        vm.startBroadcast();

        address logic = address(new CollatorStakingHub());
        // Core.upgradeProxyTo(hub, logic, "");
        // require(logic == Upgrades.getImplementationAddress(hub));
        safeconsole.log("logic: ", logic);

        vm.stopBroadcast();
    }
}
