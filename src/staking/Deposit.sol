// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@4.9.6/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721Burnable.sol";
import "./CollatorStaking.sol";

contract Deposit is ERC721, ERC721URIStorage, ERC721Burnable {
    uint256 private _nextTokenId;

    CollatorStaking collator;

    // tokenId => shares
    mapping(uint256 => uint256) public sharesOf;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) EIP712(name, "1") {}

    function votesOf(uint256 shares) public view virtual returns (uint256) {
        return collator.convertToAssets(shares);
    }

    function deposit() external payable nonreentrant {
        require(msg.value > 0);
        _mint(msg.sender, msg.value);

        emit Deposit();
    }

    function redeem(uint256 nftId) external nonreentrant {
        uint256 shares = nft.sharesOf[nftId];
        _burn(nftId);
        msg.sender.call{value: shares}();
        emit Withdraw();
    }

    function _mint(address to, uint256 shares) internal {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        sharesOf[tokenId] = shares;
    }

    function _burn(uint256 tokenId) public override {
        super._burn(tokenId);
        delete sharesOf[tokenId];
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
