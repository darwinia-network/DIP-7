// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@4.9.6/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721Burnable.sol";

contract StDeposit is ERC721, ERC721URIStorage, ERC721Burnable {
    address public factory;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) EIP712(name, "1") {
        factory = msg.sender;
    }
}
