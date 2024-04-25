// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@4.9.6/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts@4.9.6/access/Ownable.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC20/extensions/ERC20Votes.sol";

contract StRING is ERC20, ERC20Burnable, Ownable2Step, ERC20Permit, ERC20Votes {
    constructor(address owner)
        ERC20("Darwinia staked RING", "stRING")
        Ownable(owner)
        ERC20Permit("Darwinia staked RING")
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
