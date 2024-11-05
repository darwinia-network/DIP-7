// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {safeconsole} from "forge-std/safeconsole.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {RingDAOTimelockController} from "../src/governance/RingDAOTimelockController.sol";
import {RingDAO, IVotes, TimelockControllerUpgradeable} from "../src/governance/RingDAO.sol";

contract TallyScript is Script {
    address gRING = 0xdafa555e2785DC8834F4Ea9D1ED88B6049142999;
    address timelock = 0x4DCf0f14cC58fc2Bf313e70573dDB7309523bb23;

    function run() public {
        vm.startBroadcast();

        // deploy RingDAO
        address ringDAO_PROXY = Upgrades.deployTransparentProxy(
            "RingDAO.sol:RingDAO",
            timelock,
            abi.encodeCall(
                RingDAO.initialize,
                (
                    IVotes(gRING),
                    TimelockControllerUpgradeable(payable(timelock)),
                    0,
                    2 weeks,
                    1_000_000 * 1e18,
                    "RingDAO"
                )
            )
        );
        safeconsole.log("RingDAO: ", ringDAO_PROXY);
        safeconsole.log("RingDAO_Logic: ", Upgrades.getImplementationAddress(ringDAO_PROXY));

        // deploy RingDAOTimelock
        address[] memory roles = new address[](1);
        roles[0] = ringDAO_PROXY;
        address timelock_PROXY = Upgrades.deployTransparentProxy(
            "RingDAOTimelockController.sol:RingDAOTimelockController",
            timelock,
            abi.encodeCall(RingDAOTimelockController.initialize, (1 days, roles, roles, address(0)))
        );
        safeconsole.log("Timelock: ", timelock_PROXY);
        safeconsole.log("Timelock_Logic: ", Upgrades.getImplementationAddress(timelock_PROXY));

        require(timelock == timelock_PROXY, "!timelock");

        vm.stopBroadcast();
    }
}
