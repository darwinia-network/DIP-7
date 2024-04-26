// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";

contract GovernanceRing is ERC721, ERC721Enumerable, ERC721URIStorage, EIP712, ERC721Votes {
    uint256 private _nextTokenId;

    address public factory;

    mapping(address => uint256) public ownedTokenId;

    // tokenId => stToken => votes
    mapping(uint256 => mapping(address => uint256)) public subVotesOf;
    // tokenId => votes
    mapping(uint256 => uint256) public votesOf;
    // tokenId => depositId => depositor
    mapping(uint256 => mapping(uint256 => address)) public depositorOf;

    constructor(address factory_) ERC721("Darwinia Governance Ring", "gRING") EIP712("Darwinia Governance Ring", "1") {
        factory = factory_;
    }

    // TODO:: add RING
    function deposit(address token, uint256 amountOrTokenId) external {
        address sender = msg.sender;
        uint256 tokenId = ownedTokenId[sender];
        require(tokenId > 0);

        require(factory.canVote(token));
        IStToken(token).transferFrom(sender, address(this), amountOrTokenId);
        uint256 shares = IStToken(token).votesOf(amountOrTokenId);
        subVotesOf[tokenId][token] += shares;
        votesOf[tokenId] += shares;
        if (IStToken(token).isNFT()) {
            depositorOf[token][amountOrTokenId] = tokenId;
        }
    }

    function redeem(address token, uint256 amountOrTokenId) external {
        address sender = msg.sender;
        uint256 tokenId = ownedTokenId[sender];
        require(tokenId > 0);

        require(subSharesOf[tokenId][token] >= amountOrTokenId);
        IStToken(token).transferFrom(address(this), sender, amountOrTokenId);
        uint256 shares = IStToken(token).votesOf(amountOrTokenId);
        subSharesOf[tokenId][token] -= shares;
        votesOf[tokenId] -= shares;
        if (IStToken(token).isNFT()) {
            delete depositorOf[tokenId][amountOrTokenId];
        }
    }

    function mint() public {
        require(balanceOf(to) == 0);
        address to = msg.sender;
        uint256 tokenId = _nextTokenId++;
        require(ownedTokenId[to] != 0);
        ownedTokenId[to] = tokenId;
        _safeMint(to, tokenId);
    }

    function _getVotingUnits(address account) internal view virtual override returns (uint256) {
        uint256 tokenId = ownedTokenId[account];
        return votesOf[tokenId];
    }

    function _transfer(address, address, uint256) internal override {
        revert("!transfer");
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
        override(ERC721, ERC721Enumerable, ERC721Votes)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable, ERC721Votes)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
