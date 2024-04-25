// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Deposit.sol";

contract STDeposit is Deposit {
    constructor(address owner, string memory name, string memory symbol) Deposit(owner, name, symbol) {}
}
