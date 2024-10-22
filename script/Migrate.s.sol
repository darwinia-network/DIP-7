// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {safeconsole} from "forge-std/safeconsole.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Core} from "openzeppelin-foundry-upgrades/internal/Core.sol";

import {CollatorStakingHub} from "../src/collator/CollatorStakingHub.sol";
import {Deposit} from "../src/deposit/Deposit.sol";

contract MigrateScript is Script {
    // address proxy = 0xa4fFAC7A5Da311D724eD47393848f694Baee7930;

    function run() public {
        vm.startBroadcast();

        // address logic = address(new CollatorStakingHub());
        address logic = address(new Deposit());
        // Core.upgradeProxyTo(proxy, logic, "");
        // require(logic == Upgrades.getImplementationAddress(proxy));
        safeconsole.log("logic: ", logic);

        vm.stopBroadcast();
    }
}
