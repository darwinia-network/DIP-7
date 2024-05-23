// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts@5.0.2/utils/Address.sol";
import "@openzeppelin/contracts@5.0.2/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts@5.0.2/access/Ownable2Step.sol";
import "../collator/interfaces/ICollatorStakingHub.sol";
import "../deposit/interfaces/IDeposit.sol";

contract GovernanceRing is ERC20, ERC20Permit, ERC20Votes, Ownable2Step {
    using Address for address payable;
    using EnumerableSet for EnumerableSet.UintSet;

    ICollatorStakingHub public HUB;
    // Deposit NFT.
    IDeposit public immutable DEPOSIT;
    // depositId => depositor
    mapping(uint256 => address) public depositorOf;

    // depositor => token => assets
    mapping(address => mapping(address => uint256)) public wrapAssetsOf;

    // depositor => wrap depositIds
    mapping(address => EnumerableSet.UintSet) private _wrapDepositsOf;

    event Wrap(address token, address account, uint256 assetsOrDepositId);
    event Unwrap(address token, address account, uint256 assetsOrDepositId);

    modifier onlyCRING(address token) {
        require(HUB.exist(token));
        _;
    }

    constructor(address dao, address dps, address hub)
        ERC20("Governance Ring", "gRING")
        ERC20Permit("Governance Ring")
        Ownable(dao)
    {
        DEPOSIT = IDeposit(dps);
        HUB = ICollatorStakingHub(hub);
    }

    function wrap() public payable {
        _mint(msg.sender, msg.value);
        wrapAssetsOf[msg.sender][address(0)] += msg.value;
        emit Wrap(address(0), msg.sender, msg.value);
    }

    function unwrap(uint256 assets) public {
        require(wrapAssetsOf[msg.sender][address(0)] >= assets);
        _burn(msg.sender, assets);
        payable(msg.sender).sendValue(assets);
        wrapAssetsOf[msg.sender][address(0)] -= assets;
        emit Unwrap(address(0), msg.sender, assets);
    }

    function wrap(address cring, uint256 assets) external onlyCRING(cring) {
        IERC20(cring).transferFrom(msg.sender, address(this), assets);
        _mint(msg.sender, assets);
        wrapAssetsOf[msg.sender][cring] += assets;
        emit Wrap(cring, msg.sender, assets);
    }

    function unwrap(address cring, uint256 assets) external onlyCRING(cring) {
        require(wrapAssetsOf[msg.sender][cring] >= assets);
        _burn(msg.sender, assets);
        IERC20(cring).transferFrom(address(this), msg.sender, assets);
        wrapAssetsOf[msg.sender][cring] -= assets;
        emit Unwrap(cring, msg.sender, assets);
    }

    function wrapNFT(uint256 depositId) public {
        DEPOSIT.transferFrom(msg.sender, address(this), depositId);
        uint256 assets = DEPOSIT.assetsOf(depositId);
        depositorOf[depositId] = msg.sender;
        _mint(msg.sender, assets);
        require(_wrapDepositsOf[msg.sender].add(depositId));
        emit Wrap(address(DEPOSIT), msg.sender, depositId);
    }

    function unwrapNFT(uint256 depositId) public {
        require(depositorOf[depositId] == msg.sender);
        uint256 assets = DEPOSIT.assetsOf(depositId);
        _burn(msg.sender, assets);
        DEPOSIT.transferFrom(address(this), msg.sender, depositId);
        require(_wrapDepositsOf[msg.sender].remove(depositId));
        emit Unwrap(address(DEPOSIT), msg.sender, depositId);
    }

    function wrapDepositsOf(address account) public view returns (uint256[] memory) {
        return _wrapDepositsOf[account].values();
    }

    function wrapDepositsLength(address account) public view returns (uint256) {
        return _wrapDepositsOf[account].length();
    }

    function wrapDepositsAt(address account, uint256 index) public view returns (uint256) {
        return _wrapDepositsOf[account].at(index);
    }

    function wrapDepositsContains(address account, uint256 depositId) public view returns (bool) {
        return _wrapDepositsOf[account].contains(depositId);
    }

    function transfer(address, uint256) public override returns (bool) {
        revert();
    }

    function transferFrom(address, address, uint256) public override returns (bool) {
        revert();
    }

    function approve(address, uint256) public override returns (bool) {
        revert();
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
