// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@4.9.6/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@4.9.6/access/Ownable.sol";
import "@openzeppelin/contracts@4.9.6/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721Votes.sol";

contract Deposit is ERC721, ERC721URIStorage, ERC721Burnable, Ownable, EIP712, ERC721Votes {
    uint256 private _nextTokenId;

    // tokenId => shares
    mapping(uint256 => uint256) public sharesOf;

    constructor(address owner, string memory name, string memory symbol)
        ERC721(name, symbol)
        Ownable(owner)
        EIP712(name, "1")
    {}

    function mint(address to, uint256 shares) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        sharesOf[tokenId] = shares;
    }

    function burn(uint256 tokenId) public override {
        super.burn(tokenId);
        delete sharesOf[tokenId];
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Votes)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Votes) {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
