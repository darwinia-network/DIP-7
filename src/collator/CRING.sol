// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts@5.0.2/token/ERC20/ERC20.sol";

contract CRING is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
}
