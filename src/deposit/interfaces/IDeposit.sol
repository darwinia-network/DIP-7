// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24;

import "@openzeppelin/contracts@5.0.2/token/ERC721/IERC721.sol";

interface IDeposit is IERC721 {
    function assetsOf(uint256 id) external view returns (uint256);
}
