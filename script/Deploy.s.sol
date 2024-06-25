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
import {RingDAO, IVotes, TimelockControllerUpgradeable} from "../src/governance/RingDAO.sol";

contract DeployScript is Script {
    address deposit = 0x0634cf1c19Ce993A468Fa7c362208141C854736c;
    address timelock = 0xDAE15e7DA1C998a650796541DF6fFEB437cC20E4;
    address gRING = 0x4Ef76E24851f694BEe6a64F6345b873081d4F308;
    address ringDAO = 0x3aaF69F34AA8527b4CEe546DD691aD24c1fB7AEa;
    address hub = 0xD497EF1C7A8732e0761d57429Df5edc17fEaD6e6;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // RingDAO-multisig
        address multisig = 0x040f331774Ed6BB161412B4cEDb1358B382aF3A5;
        safeconsole.log("Multisig: ", multisig);

        address deposit_PROXY = Upgrades.deployTransparentProxy(
            "Deposit.sol:Deposit", multisig, abi.encodeCall(Deposit.initialize, ("RING Deposit NFT", "RDPS"))
        );
        safeconsole.log("Depoist: ", deposit_PROXY);
        safeconsole.log("Depoist_Logic: ", Upgrades.getImplementationAddress(deposit_PROXY));

        uint256 minDelay = 3 days;

        address[] memory proposers = new address[](1);
        proposers[0] = ringDAO;
        address timelock_PROXY = Upgrades.deployTransparentProxy(
            "RingTimelockController.sol:RingTimelockController",
            multisig,
            abi.encodeCall(RingTimelockController.initialize, (minDelay, proposers, new address[](0), multisig))
        );
        safeconsole.log("Timelock: ", timelock_PROXY);
        safeconsole.log("Timelock_Logic: ", Upgrades.getImplementationAddress(timelock_PROXY));

        address gRING_PROXY = Upgrades.deployTransparentProxy(
            "GovernanceRing.sol:GovernanceRing",
            timelock,
            abi.encodeCall(GovernanceRing.initialize, (multisig, hub, deposit, "Governance RING", "gRING"))
        );
        safeconsole.log("gRING: ", gRING_PROXY);
        safeconsole.log("gRING_Logic: ", Upgrades.getImplementationAddress(gRING_PROXY));

        address ringDAO_PROXY = Upgrades.deployTransparentProxy(
            "RingDAO.sol:RingDAO",
            timelock,
            abi.encodeCall(
                RingDAO.initialize,
                (
                    IVotes(gRING),
                    TimelockControllerUpgradeable(payable(timelock)),
                    1 days,
                    30 days,
                    1_000_000 * 1e18,
                    "RingDAO"
                )
            )
        );
        safeconsole.log("RingDAO: ", ringDAO_PROXY);
        safeconsole.log("RingDAO_Logic: ", Upgrades.getImplementationAddress(ringDAO_PROXY));

        address hub_PROXY = Upgrades.deployTransparentProxy(
            "CollatorStakingHub.sol:CollatorStakingHub",
            timelock,
            abi.encodeCall(CollatorStakingHub.initialize, (gRING, deposit))
        );
        safeconsole.log("Hub: ", hub_PROXY);
        safeconsole.log("Hub_Logic: ", Upgrades.getImplementationAddress(hub_PROXY));

        vm.stopBroadcast();
    }
}
