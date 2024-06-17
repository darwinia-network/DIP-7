// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IDeposit is IERC721 {
    function assetsOf(uint256 id) external view returns (uint256);
    function lock(uint256 depositId) external;
    function unlock(uint256 depositId) external;
}
