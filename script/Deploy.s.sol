// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Deposit} from "../src/deposit/Deposit.sol";
import {TimelockControllerUpgradeable} from "../src/governance/TimelockControllerUpgradeable.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address dao = msg.sender;

        address deposit = Upgrades.deployTransparentProxy(
            "Deposit.sol", dao, abi.encodeCall(Deposit.initialize, ("RING Deposit NFT", "RDPS"))
        );

        vm.stopBroadcast();
    }
}
