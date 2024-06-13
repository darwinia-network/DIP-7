// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "../../src/governance/GovernanceRing.sol";
import "../deposit/Deposit.t.sol";

contract GovernanceRingTest is Test {
    GovernanceRing gRING;
    address deposit;
    address alice = address(0x0a);
    address self = address(this);
    string name = "Governance RING";
    string symbol = "gRING";

    function setUp() public {
        deposit = Upgrades.deployTransparentProxy(
            "Deposit.sol:Deposit", msg.sender, abi.encodeCall(Deposit.initialize, ("RING Deposit", "RDPS"))
        );

        vm.etch(0x0000000000000000000000000000000000000402, type(KTONMock).runtimeCode);
        gRING = GovernanceRing(
            Upgrades.deployTransparentProxy(
                "GovernanceRing.sol:GovernanceRing",
                msg.sender,
                abi.encodeCall(GovernanceRing.initialize, (self, deposit, name, symbol))
            )
        );
        gRING.grantRole(gRING.MINTER_ROLE(), self);
        gRING.grantRole(gRING.BURNER_ROLE(), self);
    }

    function test_initialize() public view {
        assertEq(address(gRING.DEPOSIT()), deposit);
        assertEq(gRING.name(), name);
        assertEq(gRING.symbol(), symbol);
    }

    function test_mint() public {
        uint256 amount = 1 ether;
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, gRING.MINTER_ROLE())
        );
        vm.prank(alice);
        gRING.mint(alice, amount);

        gRING.grantRole(gRING.MINTER_ROLE(), alice);
        vm.prank(alice);
        gRING.mint(alice, amount);
        assertEq(gRING.balanceOf(alice), amount);
    }

    function test_burn() public {
        uint256 amount = 1 ether;
        gRING.mint(alice, amount);

        assertEq(gRING.balanceOf(alice), amount);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, gRING.BURNER_ROLE())
        );
        vm.prank(alice);
        gRING.burn(alice, amount);

        gRING.grantRole(gRING.BURNER_ROLE(), alice);
        vm.prank(alice);
        gRING.burn(alice, amount);
        assertEq(gRING.balanceOf(alice), 0);
    }

    function test_wrapRING() public {
        uint256 amount = 1 ether;
        vm.deal(alice, amount);
        vm.prank(alice);
        gRING.wrapRING{value: amount}();

        assertEq(gRING.balanceOf(alice), amount);
        assertEq(gRING.wrapAssets(alice, gRING.RING()), amount);
    }

    function test_unwrapRING() public {
        uint256 amount = 1 ether;
        vm.deal(alice, amount);
        vm.prank(alice);
        gRING.wrapRING{value: amount}();

        vm.prank(alice);
        gRING.unwrapRING(amount);
        assertEq(gRING.balanceOf(alice), 0);
        assertEq(gRING.wrapAssets(alice, gRING.RING()), 0);
    }

    function test_wrapDeposit() public {
        uint256 stake = 1 ether;
        vm.deal(alice, stake);
        vm.prank(alice);
        uint256 id = Deposit(deposit).deposit{value: stake}(1);

        vm.prank(alice);
        Deposit(deposit).approve(address(gRING), id);
        vm.prank(alice);
        gRING.wrapDeposit(id);
        assertEq(gRING.balanceOf(alice), stake);
        assertEq(gRING.wrapAssets(alice, deposit), stake);
        assertEq(gRING.wrapDepositsLength(alice), 1);
        uint256[] memory deposits = gRING.wrapDepositsOf(alice);
        assertEq(deposits.length, 1);
        assertEq(deposits[0], id);
        assertEq(gRING.wrapDepositsAt(alice, 0), id);
        assertTrue(gRING.wrapDepositsContains(alice, id));
    }

    function test_unwrapDeposit() public {
        uint256 stake = 1 ether;
        vm.deal(alice, stake);
        vm.prank(alice);
        uint256 id = Deposit(deposit).deposit{value: stake}(1);

        vm.prank(alice);
        Deposit(deposit).approve(address(gRING), id);
        vm.prank(alice);
        gRING.wrapDeposit(id);

        vm.prank(alice);
        gRING.unwrapDeposit(id);
        assertEq(gRING.balanceOf(alice), 0);
        assertEq(gRING.wrapAssets(alice, deposit), 0);
        assertEq(gRING.wrapDepositsLength(alice), 0);
        uint256[] memory deposits = gRING.wrapDepositsOf(alice);
        assertEq(deposits.length, 0);
        assertTrue(!gRING.wrapDepositsContains(alice, id));
    }
}
