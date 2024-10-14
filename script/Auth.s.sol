// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {safeconsole} from "forge-std/safeconsole.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Core} from "openzeppelin-foundry-upgrades/internal/Core.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract AuthScript is Script {
    address deployer = 0x5d3c814F82Ef2b22101635f8C6A3e7C8E09E7DD6;
    address deposit = 0x46275d29113f065c2aac262f34C7a3d8a8B7377D;
    address gRING = 0xdafa555e2785DC8834F4Ea9D1ED88B6049142999;
    address hub = 0xa4fFAC7A5Da311D724eD47393848f694Baee7930;

    address ktonDAOTimelock = 0x08837De0Ae21C270383D9F2de4DB03c7b1314632;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    function getRingDao() public view returns (address) {
        if (block.chainid == 44) {
            return 0x663fC3000f0101BF16FDc9F73F02DA6Efa8c5875;
        } else if (block.chainid == 46) {
            revert("TODO");
        } else {
            revert("unsupported");
        }
    }

    function run() public {
        vm.startBroadcast();

        // transfer deposit proxy admin ownership
        Ownable depositProxyAdmin = Ownable(Upgrades.getAdminAddress(deposit));
        if (depositProxyAdmin.owner() == deployer) {
            depositProxyAdmin.transferOwnership(ktonDAOTimelock);
        }
        require(depositProxyAdmin.owner() == ktonDAOTimelock, "!deposit");

        // transfer hub proxy admin ownership
        address ringDao = getRingDao();
        Ownable hubProxyAdmin = Ownable(Upgrades.getAdminAddress(hub));
        if (hubProxyAdmin.owner() == deployer) {
            hubProxyAdmin.transferOwnership(ringDao);
        }
        require(hubProxyAdmin.owner() == ringDao, "!hub");

        // gRING grant RingDAO admin role, deplyer renounce
        require(IAccessControl(gRING).hasRole(DEFAULT_ADMIN_ROLE, deployer), "!admin1");
        IAccessControl(gRING).grantRole(DEFAULT_ADMIN_ROLE, ringDao);
        require(IAccessControl(gRING).hasRole(DEFAULT_ADMIN_ROLE, ringDao), "!admin2");
        IAccessControl(gRING).renounceRole(DEFAULT_ADMIN_ROLE, deployer);
        require(!IAccessControl(gRING).hasRole(DEFAULT_ADMIN_ROLE, deployer), "!renounce");

        // transfer gRING proxy admin ownership
        Ownable gRINGProxyAdmin = Ownable(Upgrades.getAdminAddress(gRING));
        if (gRINGProxyAdmin.owner() == deployer) {
            gRINGProxyAdmin.transferOwnership(ringDao);
        }
        require(gRINGProxyAdmin.owner() == ringDao, "!gRING");

        vm.stopBroadcast();
    }
}
