// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract GovernanceRing is ERC20, ERC20Permit, ERC20Votes, Ownable2Step {
    constructor(address dao) ERC20("Governance Ring", "gRING") ERC20Permit("Governance Ring") Ownable2Step(dao) {}

    address public hub;
    // Deposti NFT
    address public nft;
    // depositId => depositor
    mapping(uint256 => address) public depositorOf;

    // collator => account => balance
    mapping(address => mapping(address => uint256)) public mintedMap;

    modifier onlyHub() {
        require(msg.sender == hub);
        _;
    }

    function _transfer(address, address, uint256) internal pure override {
        revert();
    }

    function _approve(address, address, uint256) internal pure override {
        revert();
    }

    function sync(address collator, address account) external onlyHub {
        _sync(collator, account);
    }

    function _sync(address collator, address account) internal {
        uint256 assets = collator.assetsOf(account);
        uint256 amount = mintedMap[collator][account];

        if (amount < assets) {
            uint256 needMint = assets - amount;
            mintedMap[collator][account] = assets;
            _mint(account, needMint);
        } else if (amount > assets) {
            uint256 needBurn = amount - assets;
            mintedMap[collator][account] = assets;
            _burn(account, needBurn);
        }
    }

    function wrap() public payable {
        _mint(msg.sender, msg.value);
    }

    function unwrap(uint256 amount) public {
        _burn(msg.sender, amount);
        msg.sender.transfer(amount);
    }

    function wrapNFT(uint256 depositId) public {
        nft.transferFrom(msg.sender, address(this), depositId);
        uint256 assets = nfg.assetsOf(depositId);
        depositorOf[depositId] = msg.sender;
        _mint(msg.sender, assets);
    }

    function unwrapNFT(uint256 depositId) public {
        require(depositorOf[depositId] == msg.sender);
        uint256 assets = nfg.assetsOf(depositId);
        _burn(msg.sernder, assets);
        fnt.transferFrom(address(this), msg.sender, depositId);
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
