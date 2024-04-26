// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@4.9.6/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@4.9.6/access/Ownable.sol";

contract Deposit is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    uint256 private _nextTokenId;

    // tokenId => shares
    mapping(uint256 => uint256) public sharesOf;

    constructor(address owner, string memory name, string memory symbol)
        ERC721(name, symbol)
        Ownable(owner)
        EIP712(name, "1")
    {}

    function deposit() external payable nonreentrant {
        require(msg.value > 0);
        nft.mint(msg.sender, msg.value);

        emit Deposit();
    }

    function redeem(uint256 nftId) external nonreentrant {
        uint256 shares = nft.sharesOf[nftId];
        nft.burn(nftId);
        msg.sender.call{value: shares}();
        emit Withdraw();
    }

    function mint(address to, uint256 shares) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        sharesOf[tokenId] = shares;
    }

    function burn(uint256 tokenId) public override {
        super.burn(tokenId);
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
