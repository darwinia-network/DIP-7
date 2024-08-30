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
    address deployer = 0xF98F1A9187fDA37E4aDC82cC4063ADEF701339bc;
    address deposit = 0xDeC9cD45e921F2AedE72f694743265af37d47Fa7;
    address gRING = 0xd677D6461870DD88B915EBa76954D1a15114B42d;
    address hub = 0xb037E75fE2BFA42DdDC17BB90963Dafe10A5Dd11;

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
