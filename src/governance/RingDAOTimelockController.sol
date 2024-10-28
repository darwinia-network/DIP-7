// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

contract RingDAOTimelockController is
    Initializable,
    TimelockControllerUpgradeable,
    AccessControlEnumerableUpgradeable
{
    function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        public
        initializer
    {
        __TimelockController_init(minDelay, proposers, executors, admin);
        __AccessControlEnumerable_init();
    }

    function _grantRole(bytes32 role, address account)
        internal
        override(AccessControlUpgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return super._grantRole(role, account);
    }

    function _revokeRole(bytes32 role, address account)
        internal
        override(AccessControlUpgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return super._revokeRole(role, account);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(TimelockControllerUpgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
