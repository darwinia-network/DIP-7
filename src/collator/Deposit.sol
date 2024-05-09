// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@4.9.6/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721Burnable.sol";
import "./CollatorStaking.sol";

contract Deposit is ERC721, ERC721URIStorage, ERC721Burnable {
    uint256 private _nextTokenId;

    // tokenId => lockedAssets
    mapping(uint256 => uint256) public assetsOf;

    constructor() ERC721("Deposit NFT", "DPS") EIP712("Deposit NFT", "1") {}

    function lock() external payable {
        require(msg.value > 0);
        _mint(msg.sender, msg.value);

        emit Deposit();
    }

    function unlock(uint256 nftId) external {
        uint256 assets = assetsOf[nftId];
        _burn(nftId);
        msg.sender.call{value: assets}();
        emit Withdraw();
    }

    function _mint(address to, uint256 assets) internal {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        assetsOf[tokenId] = assets;
    }

    function _burn(uint256 tokenId) public override {
        super._burn(tokenId);
        delete assetsOf[tokenId];
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
