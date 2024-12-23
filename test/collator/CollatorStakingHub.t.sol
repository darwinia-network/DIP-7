// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../deposit/Deposit.t.sol";
import "../../src/collator/CollatorStakingHub.sol";
import "../../src/deposit/Deposit.sol";

contract CollatorStakingHubTest is Test {
    address gring;
    address deposit;
    CollatorStakingHub hub;

    address internal constant HEAD = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
    address internal constant TAIL = address(0x1);
    address alith = address(0x0a);
    address baltathar = address(0x0b);
    address charleth = address(0xc);
    address alice = address(0xaa);
    address bob = address(0xbb);

    uint256 REWARDS_DURATION = 7 days;

    function setUp() public {
        gring = address(new GRINGMock());
        deposit = Upgrades.deployTransparentProxy(
            "Deposit.sol:Deposit", msg.sender, abi.encodeCall(Deposit.initialize, ("RING Deposit", "RDPS"))
        );

        vm.etch(0x0000000000000000000000000000000000000402, type(KTONMock).runtimeCode);
        hub = CollatorStakingHub(
            Upgrades.deployTransparentProxy(
                "CollatorStakingHub.sol:CollatorStakingHub",
                msg.sender,
                abi.encodeCall(CollatorStakingHub.initialize, (gring, deposit))
            )
        );
    }

    function test_initialize() public view {
        assertEq(gring, hub.gRING());
        assertEq(deposit, hub.DEPOSIT());
    }

    function test_createAndCollate() public {
        vm.prank(alith);
        address a = hub.createAndCollate(HEAD, 1);
        assertEq(NominationPool(a).hub(), address(hub));
        assertEq(NominationPool(a).collator(), alith);
        vm.prank(baltathar);
        address b = hub.createAndCollate(HEAD, 2);
        assertEq(NominationPool(b).hub(), address(hub));
        assertEq(NominationPool(b).collator(), baltathar);
        vm.prank(charleth);
        address c = hub.createAndCollate(HEAD, 3);
        assertEq(NominationPool(c).hub(), address(hub));
        assertEq(NominationPool(c).collator(), charleth);
        assertEq(hub.collators(HEAD), charleth);
        assertEq(hub.collators(charleth), baltathar);
        assertEq(hub.collators(baltathar), alith);
        assertEq(hub.collators(alith), TAIL);
        assertEq(hub.stakedOf(alith), 0);
        assertEq(hub.stakedOf(baltathar), 0);
        assertEq(hub.stakedOf(charleth), 0);
    }

    function test_updateCommission() public {
        vm.prank(alith);
        address a = hub.createAndCollate(HEAD, 1);

        vm.warp(block.timestamp + hub.COMMISSION_LOCK_PERIOD() + 1);

        vm.prank(alith);
        vm.expectRevert(bytes("same"));
        hub.updateCommission(1, HEAD, HEAD);

        vm.prank(alith);
        hub.updateCommission(2, HEAD, HEAD);
        assertEq(hub.commissionOf(alith), 2);

        vm.prank(alith);
        vm.expectRevert("!locked");
        hub.updateCommission(3, HEAD, HEAD);

        vm.warp(block.timestamp + hub.COMMISSION_LOCK_PERIOD() + 1);
        vm.prank(alith);
        hub.updateCommission(3, HEAD, HEAD);
        assertEq(hub.commissionOf(alith), 3);
    }

    function test_stakeRING() public {
        uint256 stake = 1 ether;
        vm.prank(alith);
        uint256 commissoin = 1;
        address a = hub.createAndCollate(HEAD, commissoin);
        vm.deal(alice, stake);
        vm.prank(alice);
        hub.stakeRING{value: stake}(alith, HEAD, HEAD);
        assertEq(hub.stakedRINGOf(alith, alice), stake);
        assertEq(NominationPool(a).balanceOf(alice), stake);
        assertEq(hub.votesOf(alith), stake * (100 - commissoin) / 100);
        assertEq(hub.stakedOf(alith), stake);
        assertEq(IERC20(gring).balanceOf(alice), stake);
    }

    function test_claim() public {
        uint256 stake = 1 ether;
        uint256 commissoin = 1;
        vm.prank(alith);
        address a = hub.createAndCollate(HEAD, commissoin);

        vm.deal(alice, stake);
        vm.prank(alice);
        hub.stakeRING{value: stake}(alith, HEAD, HEAD);

        uint256 reward = 100 ether;
        vm.deal(hub.SYSTEM_PALLET(), reward);
        vm.prank(hub.SYSTEM_PALLET());
        hub.distributeReward{value: reward}(alith);

        vm.warp(NominationPool(a).periodFinish() + 1);

        vm.prank(alice);
        hub.claim(alith);
        assertEq(alice.balance, reward * (100 - commissoin) / 100 / REWARDS_DURATION * REWARDS_DURATION);
        assertEq(alith.balance, reward * commissoin / 100);
    }

    function test_unstakeRING() public {
        uint256 stake = 1 ether;
        uint256 commissoin = 1;
        vm.prank(alith);
        address a = hub.createAndCollate(HEAD, commissoin);

        vm.deal(alice, stake);
        vm.prank(alice);
        hub.stakeRING{value: stake}(alith, HEAD, HEAD);
        assertEq(hub.stakingLocks(alith, alice), hub.STAKING_LOCK_PERIOD() + block.timestamp);

        vm.warp(block.timestamp + hub.STAKING_LOCK_PERIOD() + 1);

        vm.prank(alice);
        hub.unstakeRING(alith, stake, HEAD, HEAD);
        assertEq(alice.balance, stake);
        assertEq(hub.stakedOf(alith), 0);
        assertEq(IERC20(gring).balanceOf(alice), 0);
    }

    function test_unstakeRINGFromInactiveCollator() public {
        uint256 stake = 1 ether;
        uint256 commissoin = 1;
        vm.prank(alith);
        address a = hub.createAndCollate(HEAD, commissoin);

        vm.deal(alice, stake);
        vm.prank(alice);
        hub.stakeRING{value: stake}(alith, HEAD, HEAD);
        assertEq(hub.stakingLocks(alith, alice), hub.STAKING_LOCK_PERIOD() + block.timestamp);

        vm.warp(block.timestamp + hub.STAKING_LOCK_PERIOD() + 1);

        vm.prank(alith);
        hub.stopCollation(HEAD);

        vm.prank(alice);
        hub.unstakeRINGFromInactiveCollator(alith, stake);
        assertEq(alice.balance, stake);
        assertEq(hub.stakedOf(alith), 0);
        assertEq(IERC20(gring).balanceOf(alice), 0);
    }

    function test_stakeDeposit() public {
        uint256 stake = 1 ether;
        vm.deal(alice, stake);
        vm.prank(alice);
        uint256 id = Deposit(deposit).deposit{value: stake}(1);

        uint256 commissoin = 1;
        vm.prank(alith);
        address a = hub.createAndCollate(HEAD, commissoin);

        vm.prank(alice);
        Deposit(deposit).approve(address(hub), id);
        vm.prank(alice);
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        hub.stakeDeposits(alith, ids, HEAD, HEAD);
        assertEq(hub.stakingLocks(alith, alice), hub.STAKING_LOCK_PERIOD() + block.timestamp);
        (address account, uint256 assets, address collator) = hub.depositInfos(id);
        assertEq(account, alice);
        assertEq(assets, stake);
        assertEq(collator, alith);
        assertEq(hub.stakedDepositsLength(alice), 1);
        uint256[] memory deposits = hub.stakedDepositsOf(alice);
        assertEq(deposits.length, 1);
        assertEq(deposits[0], id);
        assertEq(hub.stakedDepositsAt(alice, 0), id);
        assertTrue(hub.stakedDepositsContains(alice, id));
        assertEq(NominationPool(a).balanceOf(alice), stake);
        assertEq(hub.votesOf(alith), stake * (100 - commissoin) / 100);
        assertEq(hub.stakedOf(alith), stake);
        assertEq(IERC20(gring).balanceOf(alice), stake);
    }

    function test_unstakeDeposit() public {
        uint256 stake = 1 ether;
        vm.deal(alice, stake);
        vm.prank(alice);
        uint256 id = Deposit(deposit).deposit{value: stake}(1);

        uint256 commissoin = 1;
        vm.prank(alith);
        address a = hub.createAndCollate(HEAD, commissoin);

        vm.prank(alice);
        Deposit(deposit).approve(address(hub), id);
        vm.prank(alice);
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        hub.stakeDeposits(alith, ids, HEAD, HEAD);

        vm.warp(block.timestamp + hub.STAKING_LOCK_PERIOD() + 1);

        vm.prank(alice);
        hub.unstakeDeposits(alith, ids, HEAD, HEAD);

        (address account, uint256 assets, address collator) = hub.depositInfos(id);
        assertEq(account, address(0));
        assertEq(assets, 0);
        assertEq(collator, address(0));
        assertEq(hub.stakedDepositsLength(alice), 0);
        uint256[] memory deposits = hub.stakedDepositsOf(alice);
        assertEq(deposits.length, 0);
        assertTrue(!hub.stakedDepositsContains(alice, id));
        assertEq(NominationPool(a).balanceOf(alice), 0);
        assertEq(hub.votesOf(alith), 0);
        assertEq(hub.stakedOf(alith), 0);
        assertEq(IERC20(gring).balanceOf(alice), 0);
    }

    function test_unstakeDepositFromInactiveCollator() public {
        uint256 stake = 1 ether;
        vm.deal(alice, stake);
        vm.prank(alice);
        uint256 id = Deposit(deposit).deposit{value: stake}(1);

        uint256 commissoin = 1;
        vm.prank(alith);
        address a = hub.createAndCollate(HEAD, commissoin);

        vm.prank(alice);
        Deposit(deposit).approve(address(hub), id);
        vm.prank(alice);
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        hub.stakeDeposits(alith, ids, HEAD, HEAD);

        vm.warp(block.timestamp + hub.STAKING_LOCK_PERIOD() + 1);

        vm.prank(alith);
        hub.stopCollation(HEAD);

        assertEq(hub.votesOf(alith), 0);
        assertEq(hub.stakedOf(alith), stake);

        vm.prank(alice);
        hub.unstakeDepositsFromInactiveCollator(alith, ids);

        (address account, uint256 assets, address collator) = hub.depositInfos(id);
        assertEq(account, address(0));
        assertEq(assets, 0);
        assertEq(collator, address(0));
        assertEq(hub.stakedDepositsLength(alice), 0);
        uint256[] memory deposits = hub.stakedDepositsOf(alice);
        assertEq(deposits.length, 0);
        assertTrue(!hub.stakedDepositsContains(alice, id));
        assertEq(NominationPool(a).balanceOf(alice), 0);
        assertEq(hub.votesOf(alith), 0);
        assertEq(hub.stakedOf(alith), 0);
        assertEq(IERC20(gring).balanceOf(alice), 0);
    }

    function test_lossOfPrecision() public {
        uint256 stake = 1;
        uint256 total = 3;
        uint256 commissoin = 30;
        vm.prank(alith);
        address a = hub.createAndCollate(HEAD, commissoin);

        vm.deal(alice, total);
        vm.prank(alice);
        hub.stakeRING{value: stake}(alith, HEAD, HEAD);
        assertEq(hub.votesOf(alith), 0);

        vm.prank(alice);
        hub.stakeRING{value: stake}(alith, HEAD, HEAD);
        assertEq(hub.votesOf(alith), 1);

        vm.prank(alice);
        hub.stakeRING{value: stake}(alith, HEAD, HEAD);
        assertEq(hub.votesOf(alith), 2);

        vm.warp(block.timestamp + hub.STAKING_LOCK_PERIOD() + 1);

        vm.prank(alice);
        hub.unstakeRING(alith, total, HEAD, HEAD);
        assertEq(hub.stakedOf(alith), 0);
        assertEq(hub.votesOf(alith), 0);
    }
}

contract GRINGMock is ERC20 {
    constructor() ERC20("Governance RINGMock", "gRINGM") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
