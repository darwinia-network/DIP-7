// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract CollatorStakingHubStorage {
    // ---------------------- CollatorSetStorage ----------------------------
    // collator count;
    uint256 public count;
    // ordered collators.
    mapping(address => address) public collators;
    // collator => votes = staked_ring * (1 - commission)
    mapping(address => uint256) public votesOf;

    // ---------------------- CollatorStakingHubStorage ---------------------
    // collator => stakingPool
    mapping(address => address) public poolOf;
    // stakingPool => collator
    mapping(address => address) public collatorOf;
    // collator => commission
    mapping(address => uint256) public commissionOf;
    // user => staked ring
    mapping(address => uint256) public stakedRINGOf;
    // user => staked depositIds
    mapping(address => EnumerableSet.UintSet) internal _stakedDeposits;

    struct DepositInfo {
        address account;
        uint256 assets;
        address collator;
    }

    // depositId => depositInfo
    mapping(uint256 => DepositInfo) public depositInfos;
}