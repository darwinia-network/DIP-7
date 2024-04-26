// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Deposit.sol";

contract StDeposit is Deposit {
    address public factory;

    constructor(string memory name, string memory symbol) Deposit(name, symbol) {
        factory = msg.sender;
    }
}
