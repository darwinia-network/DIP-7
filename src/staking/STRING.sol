// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@4.9.6/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts@4.9.6/access/Ownable.sol";
import "./CollatorStaking.sol";

contract StRING is ERC20, ERC20Burnable, Ownable2Step {
    constructor(address owner) ERC20("Darwinia staked RING", "stRING") Ownable(owner) {}

    CollatorStaking collator;

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function votesOf(uint256 shares) public view virtual returns (uint256) {
        return collator.convertToAssets(shares);
    }
}
