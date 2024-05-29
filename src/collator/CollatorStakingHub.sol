// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts@5.0.2/utils/Strings.sol";
import "@openzeppelin/contracts@5.0.2/utils/Address.sol";
import "@openzeppelin/contracts@5.0.2/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts@5.0.2/utils/ReentrancyGuard.sol";
import "./interfaces/ICollatorStaking.sol";
import "./CollatorStaking.sol";
import "./CollatorSet.sol";
import "../deposit/interfaces/IDeposit.sol";

// TODO:
//   1. how to set session key.
contract CollatorStakingHub is CollatorSet, ReentrancyGuard {
    using Strings for uint256;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.UintSet;

    // operator => collator
    mapping(address => address) public collatorOf;

    // collator => commission
    mapping(address => uint256) public commissionOf;

    struct DepositInfo {
        address account;
        uint256 assets;
        address collator;
    }

    // user => staked ring
    mapping(address => uint256) public stakedRINGOf;
    // user => staked depositIds
    mapping(address => EnumerableSet.UintSet) private _stakedDepositsOf;
    // depositId => depositInfo
    mapping(uint256 => DepositInfo) public depositInfoOf;

    // Deposit NFT.
    IDeposit public immutable DEPOSIT;
    // TODO:
    address public constant STAKING_PALLET = address(0);
    // 0 ~ 100
    uint256 private constant COMMISSION_BASE = 100;

    event Staked(address indexed collator, address account, uint256 assets);
    event Unstaked(address indexed collator, address account, uint256 assets);
    event CollatorCreated(address indexed collator, address operator, address prev);
    event CommissionUpdated(address indexed collator, uint256 commission);

    modifier onlySystem() {
        require(msg.sender == STAKING_PALLET, "!system");
        _;
    }

    modifier checkExist(collator) {
        require(exist(collator), "!exist");
        _;
    }

    constructor(address dps) CollatorSet() {
        DEPOSIT = IDeposit(dps);
    }

    function createCollator(address prev, uint256 commission) public returns (address collator) {
        address operator = msg.sender;
        require(collatorOf[operator] == address(0), "created");

        uint256 index = count;
        string memory indexStr = index.toString();
        string memory name = string.concat("Collator Staking RING-", indexStr);
        string memory symbol = string.concat("CRING-", indexStr);

        bytes memory bytecode = type(CollatorStaking).creationCode;
        bytes memory initCode = bytes.concat(bytecode, abi.encode(operator, name, symbol));
        assembly {
            collator := create2(0, add(initCode, 32), mload(initCode), 0)
        }
        require(collator != address(0), "!create2");

        collatorOf[operator] = address(collator);
        _addCollator(collator, 0, prev);
        _collect(collator, commission);
        emit CollatorCreated(collator, operator, prev);
    }

    function _stake(address collator, address account, uint256 assets) internal checkExist(collator) {
        ICollatorStaking(collator).stake(account, assets);
        emit Staked(collator, account, assets);
    }

    function _unstake(address collator, address account, uint256 assets) internal checkExist(collator) {
        ICollatorStaking(collator).withdraw(account, assets);
        emit Unstaked(collator, account, assets);
    }

    function stakeRING(address collator, address oldPrev, address newPrev) public payable nonReentrant {
        _stake(collator, msg.sender, msg.value);
        _increaseScore(collator, _assetsToScore(commissionOf[collator], msg.value), oldPrev, newPrev);
        stakedRINGOf[msg.sender] += msg.value;
    }

    function unstakeRING(address collator, uint256 assets, address oldPrev, address newPrev) public nonReentrant {
        _unstake(collator, msg.sender, assets);
        payable(account).sendValue(assets);
        _reduceScore(collator, _assetsToScore(commissionOf[collator], assets), oldPrev, newPrev);
        stakedRINGOf[msg.sender] -= assets;
    }

    function stakeNFT(address collator, uint256 depositId, address oldPrev, address newPrev) public nonReentrant {
        address account = msg.sender;
        DEPOSIT.transferFrom(account, address(this), depositId);
        uint256 assets = DEPOSIT.assetsOf(depositId);
        depositInfoOf[depositId] = DepositInfo(account, assets, collator);

        _stake(collator, account, assets);
        _increaseScore(collator, _assetsToScore(commissionOf[collator], assets), oldPrev, newPrev);
        require(_stakedDepositsOf[account].add(depositId), "!add");
    }

    function unstakeNFT(uint256 depositId, address oldPrev, address newPrev) public nonReentrant {
        address account = msg.sender;
        DepositInfo memory info = depositInfoOf[depositId];
        require(info.account == account);
        DEPOSIT.transferFrom(address(this), account, depositId);
        delete depositInfoOf[depositId];

        _unstake(info.collator, info.account, info.assets);
        _reduceScore(info.collator, _assetsToScore(commissionOf[info.collator], info.assets), oldPrev, newPrev);
        require(_stakedDepositsOf[account].remove(depositId), "!remove");
    }

    function claim(address collator) public checkExist(collator) nonReentrant {
        ICollatorStaking(collator).getReward(msg.sender);
    }

    function collect(uint256 commission, address oldPrev, address newPrev) public checkExist(collator) nonReentrant {
        address collator = collatorOf[msg.sender];
        _removeCollator(collator, oldPrev);
        _collect(collator, commission);
        _addCollator(collator, _assetsToScore(commission, stakedOf(collator)), newPrev);
    }

    function distributeReward(address collator) public payable checkExist(collator) onlySystem {
        uint256 rewards = msg.value;
        uint256 commission_ = rewards * commissionOf[collator] / COMMISSION_BASE;
        address operator = ICollatorStaking(collator).operator();
        payable(operator).sendValue(commission_);
        ICollatorStaking(collator).notifyRewardAmount{value: rewards - commission_}();
    }

    function stakedOf(address collator) public view returns (uint256) {
        return IERC20(collator).totalSupply();
    }

    function _collect(address collator, uint256 commission) internal {
        require(commission <= COMMISSION_BASE);
        commissionOf[collator] = commission;
        emit CommissionUpdated(collator, commission);
    }

    function _assetsToScore(uint256 commission, uint256 assets) internal pure returns (uint256) {
        return assets * (100 - commission) / 100;
    }

    function stakedDepositsOf(address account) public view returns (uint256[] memory) {
        return _stakedDepositsOf[account].values();
    }

    function stakedDepositsLength(address account) public view returns (uint256) {
        return _stakedDepositsOf[account].length();
    }

    function stakedDepositsAt(address account, uint256 index) public view returns (uint256) {
        return _stakedDepositsOf[account].at(index);
    }

    function stakedDepositsContains(address account, uint256 depositId) public view returns (bool) {
        return _stakedDepositsOf[account].contains(depositId);
    }
}
