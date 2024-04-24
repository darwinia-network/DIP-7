// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./StakingRewards.sol";

contract CollatorStaking is StakingRewards {
    constructor(address _rewardsDistribution, address wring) StakingRewards(_rewardsDistribution, wring) {}
}
