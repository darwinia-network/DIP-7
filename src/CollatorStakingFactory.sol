// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-solidity-4.9.6/contracts/utils/structs/EnumerableSet.sol";
import "./CollatorStaking.sol";

contract CollatorStakingFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private collators;
    address public depositNFT;
    address public distribution;
    address public wring;

    mapping(address => address) public collatorOf;

    function createCollator() public {
        address creator = msg.sender;
        require(collatorOf[user] == address(0));
        STRING stRing = new STRING();
        CollatorStaking collator = new CollatorStaking(distribution, stRing, depositNFT, wring, creator);
        require(collators.add(collator));
    }
}
