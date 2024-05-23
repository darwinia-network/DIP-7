// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24;

import "@openzeppelin/contracts@5.0.2/token/ERC20/IERC20.sol";

interface IKTON is IERC20 {
    function burn(address from, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external returns (bool);
}
