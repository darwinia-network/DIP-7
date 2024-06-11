// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {safeconsole} from "forge-std/safeconsole.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../src/deposit/Deposit.sol";

contract DepositTest is Test, ERC721Holder {
    string name = "RING Deposit";
    string symbol = "RDPS";
    address deposit;
    address KTON = 0x0000000000000000000000000000000000000402;
    address self = address(this);

    receive() external payable {}

    function setUp() public {
        deposit = Upgrades.deployTransparentProxy(
            "Deposit.sol:Deposit", msg.sender, abi.encodeCall(Deposit.initialize, (name, symbol))
        );
        bytes memory code = vm.getDeployedCode("Deposit.t.sol:KTONMock");
        vm.etch(KTON, code);
    }

    function test_initialize() public view {
        assertEq(IERC721Metadata(deposit).name(), name);
        assertEq(IERC721Metadata(deposit).symbol(), symbol);
        assertEq(IERC721Enumerable(deposit).totalSupply(), 0);
    }

    function test_deposit() public {
        uint256 id = Deposit(deposit).deposit{value: 1 ether}(1);
        assertEq(IERC721(deposit).balanceOf(self), 1);
        assertEq(IERC721(deposit).ownerOf(id), self);
        assertEq(IERC721Metadata(deposit).tokenURI(id), "");
        assertEq(IERC721Enumerable(deposit).tokenOfOwnerByIndex(self, 0), id);
        assertEq(IERC721Enumerable(deposit).tokenByIndex(0), id);
        assertEq(IERC721Enumerable(deposit).totalSupply(), 1);
        assertEq(IERC20(KTON).balanceOf(self), 7.61e16);
        assertEq(Deposit(deposit).assetsOf(id), 1 ether);
        assertEq(Deposit(deposit).isClaimRequirePenalty(id), true);
    }

    function test_claim() public {
        uint256 id = Deposit(deposit).deposit{value: 1 ether}(1);
        KTONMock(KTON).mint(self, 2.283e17);
        KTONMock(KTON).approve(deposit, 2.283e17);
        assertEq(Deposit(deposit).isClaimRequirePenalty(id), true);
        vm.warp(block.timestamp + 30 days);
        assertEq(Deposit(deposit).isClaimRequirePenalty(id), false);
        vm.expectRevert("!penalty");
        Deposit(deposit).claimWithPenalty(id);
        Deposit(deposit).claim(id);
        assertEq(IERC721(deposit).balanceOf(self), 0);
        assertEq(IERC721Enumerable(deposit).totalSupply(), 0);
    }

    function test_claimWithPenalty() public {
        uint256 id = Deposit(deposit).deposit{value: 1 ether}(1);
        vm.expectRevert("penalty");
        Deposit(deposit).claim(id);
        KTONMock(KTON).mint(self, 2.283e17);
        KTONMock(KTON).approve(deposit, 2.283e17);
        Deposit(deposit).claimWithPenalty(id);
        assertEq(IERC721(deposit).balanceOf(self), 0);
        assertEq(IERC721Enumerable(deposit).totalSupply(), 0);
    }

    function test_computeInterest() public {
        uint256 UNIT = 1 ether;
        for (uint256 m = 1; m < 37; m++) {
            uint256 interest = Deposit(deposit).INTERESTS(m);

            safeconsole.log(_computeInterest(UNIT, m));
            // assertEq(Deposit(deposit).computeInterest(UNIT, m), _computeInterest(UNIT, m));
        }
    }

    function _computeInterest(uint256 value, uint256 months) internal pure returns (uint256) {
        uint64 unitInterest = 1_000;

        // these two actually mean the multiplier is 1.015
        uint256 numerator = 67 ** months;
        uint256 denominator = 66 ** months;
        uint256 quotient = numerator / denominator;
        uint256 remainder = numerator % denominator;

        // depositing X RING for 12 months, interest is about (1 * unitInterest * X / 10**7) KTON
        // and the multiplier is about 3
        // ((quotient - 1) * 1000 + remainder * 1000 / denominator) is 197 when _month is 12.
        return (unitInterest * value) * ((quotient - 1) * 1000 + remainder * 1000 / denominator) / (197 * 10 ** 7);
    }
}

contract KTONMock is ERC20 {
    constructor() ERC20("KTONMock", "KTONM") {}

    function mint(address account, uint256 amount) external returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(address account, uint256 amount) external returns (bool) {
        _burn(account, amount);
        return true;
    }
}
