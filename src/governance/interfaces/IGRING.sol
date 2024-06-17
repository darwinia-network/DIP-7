// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGRING is IERC20 {
    function burn(address from, uint256 amount) external;
    function mint(address to, uint256 amount) external;
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}
