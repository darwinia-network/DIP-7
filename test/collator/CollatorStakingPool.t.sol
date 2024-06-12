// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../src/collator/CollatorStakingPool.sol";

contract CollatorStakingPoolTest is Test {
    CollatorStakingPool pool;
    uint256 startTime;
    uint256 endTime;
    uint256 reward = 100 ether;
    uint256 REWARDS_DURATION = 7 days;
    address self = address(this);
    address alice = address(new Guy());
    address bob = address(new Guy());

    function setUp() public {
        pool = new CollatorStakingPool(self, 0);
        assertEq(pool.rewardsDuration(), REWARDS_DURATION);
    }

    function start() public {
        pool.notifyRewardAmount{value: reward}();
        startTime = pool.lastUpdateTime();
        endTime = pool.periodFinish();
        assertEq(endTime, startTime + REWARDS_DURATION);
    }

    function invariant_hub() public {
        assertEq(pool.hub(), self);
    }

    function test_constructor() public {
        assertEq(pool.totalSupply(), 0);
    }

    function test_notifyRewardAmount_full() public {
        pool.stake(alice, 2 ether);

        start();

        vm.warp(endTime + 1);

        pool.withdraw(alice, 2 ether);
        pool.getReward(alice);
        uint256 stakeEndTime = pool.lastUpdateTime();
        assertEq(stakeEndTime, endTime);

        uint256 rewardAmount = alice.balance;
        assertTrue(reward - rewardAmount <= reward / 10000);
        assertEq(rewardAmount, (reward / REWARDS_DURATION) * REWARDS_DURATION);
    }

    function test_notifyRewardAmount_half() public {
        start();

        vm.warp((endTime - startTime) / 2 + 1);

        pool.stake(alice, 2 ether);
        uint256 stakeStartTime = pool.lastUpdateTime();

        vm.warp(endTime + 1);

        pool.withdraw(alice, 2 ether);
        pool.getReward(alice);
        uint256 stakeEndTime = pool.lastUpdateTime();
        assertEq(stakeEndTime, endTime);

        uint256 rewardAmount = alice.balance;

        assertTrue(reward / 2 - rewardAmount <= reward / 2 / 10000);
        assertEq(rewardAmount, (reward / REWARDS_DURATION) * (endTime - stakeStartTime));
    }

    function test_notifyRewardAmount_twoStakers() public {
        pool.stake(alice, 2 ether);

        start();

        vm.warp((endTime - startTime) / 2 + 1);

        pool.stake(bob, 2 ether);

        vm.warp(endTime + 1);
        pool.withdraw(alice, 2 ether);
        pool.getReward(alice);
        uint256 stakeEndTime = pool.lastUpdateTime();
        assertEq(stakeEndTime, endTime);

        pool.withdraw(bob, 2 ether);
        pool.getReward(bob);

        uint256 aliceRewardAmount = alice.balance;
        uint256 bobRewardAmount = bob.balance;
        uint256 totalReward = aliceRewardAmount + bobRewardAmount;

        assertTrue(reward - totalReward <= reward / 10000);
        assertTrue(totalReward * 3 / 4 - aliceRewardAmount <= totalReward * 3 / 4 / 10000);
        assertTrue(totalReward / 4 - bobRewardAmount <= totalReward / 4 / 10000);
    }
}

contract Guy {
    receive() external payable {}
}
