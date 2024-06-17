// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGRING is IERC20 {
    function depositFor(address account) external payable;
    function withdrawTo(address account, uint256 wad) external;
}
