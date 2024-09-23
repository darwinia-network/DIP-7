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
    address deployer = 0x5d3c814F82Ef2b22101635f8C6A3e7C8E09E7DD6;
    address deposit = 0x46275d29113f065c2aac262f34C7a3d8a8B7377D;
    address gRING = 0xdafa555e2785DC8834F4Ea9D1ED88B6049142999;
    address hub = 0xa4fFAC7A5Da311D724eD47393848f694Baee7930;

    struct Settings {
        string depositName;
        string depositSymbol;
        string gringName;
        string gringSymbol;
    }

    function getSettings(uint256 chainId) public pure returns (Settings memory) {
        if (chainId == 701) {
            return Settings({
                depositName: "KRING Deposit NFT",
                depositSymbol: "KDPS",
                gringName: "Governance KRING",
                gringSymbol: "gKRING"
            });
        } else if (chainId == 44) {
            return Settings({
                depositName: "CRAB Deposit NFT",
                depositSymbol: "CDPS",
                gringName: "Governance CRAB",
                gringSymbol: "gCRAB"
            });
        } else if (chainId == 46) {
            return Settings({
                depositName: "RING Deposit NFT",
                depositSymbol: "RDPS",
                gringName: "Governance RING",
                gringSymbol: "gRING"
            });
        }
    }

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        require(msg.sender == deployer, "!deployer");

        safeconsole.log("Chain Id: ", block.chainid);
        Settings memory s = getSettings(block.chainid);

        address deposit_PROXY = Upgrades.deployTransparentProxy(
            "Deposit.sol:Deposit", deployer, abi.encodeCall(Deposit.initialize, (s.depositName, s.depositSymbol))
        );
        safeconsole.log("Depoist: ", deposit_PROXY);
        safeconsole.log("Depoist_Logic: ", Upgrades.getImplementationAddress(deposit_PROXY));

        address gRING_PROXY = Upgrades.deployTransparentProxy(
            "GovernanceRing.sol:GovernanceRing",
            deployer,
            abi.encodeCall(GovernanceRing.initialize, (deployer, hub, deposit, s.gringName, s.gringSymbol))
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
