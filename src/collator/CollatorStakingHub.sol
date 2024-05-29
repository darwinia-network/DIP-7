// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts@5.0.2/utils/Strings.sol";
import "@openzeppelin/contracts@5.0.2/utils/Address.sol";
import "@openzeppelin/contracts@5.0.2/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/IERC721.sol";
import "./interfaces/ICollatorStaking.sol";
import "./CollatorStaking.sol";
import "./CollatorSet.sol";
import "../deposit/interfaces/IDeposit.sol";

// TODO:
//   1. how to set session key.
//   2. change collator operator.
contract CollatorStakingHub is CollatorSet {
    using Strings for uint256;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.UintSet;

    // operator => collator
    mapping(address => address) public collatorOf;

    // collator => commission
    mapping(address => uint256) public commissionOf;

    // collator => staked ring
    mapping(address => uint256) public assetsOf;

    struct DepositInfo {
        address account;
        uint256 assets;
        address collator;
    }

    // depositor => staked ring
    mapping(address => uint256) public stakedRINGOf;
    // depositor => staked depositIds
    mapping(address => EnumerableSet.UintSet) private _stakedDepositsOf;
    // depositId => depositInfo
    mapping(uint256 => DepositInfo) public depositInfoOf;

    // Deposit NFT.
    IDeposit public immutable DEPOSIT;
    // TODO:
    address public immutable STAKING_PALLET = address(0);

    // 0 ~ 100
    uint256 private constant COMMISSION_BASE = 100;

    event CollatorCreated(address indexed collator, address operator, address prev);
    event Staked(
        address indexed collator, address account, uint256 assetsOrDepositId, address oldPrev, address newPrev
    );
    event Unstaked(
        address indexed collator, address account, uint256 assetsOrDepositId, address oldPrev, address newPrev
    );
    event CommissionUpdated(address indexed collator, uint256 commission);

    constructor(address dps) CollatorSet() {
        DEPOSIT = IDeposit(dps);
    }

    function createCollator(address prev, uint256 commission) public returns (address collator) {
        address operator = msg.sender;
        require(collatorOf[operator] == address(0));

        uint256 index = count;
        string memory indexStr = index.toString();
        string memory name = string.concat("Collator Staking RING-", indexStr);
        string memory symbol = string.concat("CRING-", indexStr);

        bytes memory bytecode = type(CollatorStaking).creationCode;
        bytes memory initCode = bytes.concat(bytecode, abi.encode(operator, name, symbol));
        assembly {
            collator := create2(0, add(initCode, 32), mload(initCode), 0)
        }

        collatorOf[operator] = address(collator);
        _addCollator(collator, 0, prev);
        emit CollatorCreated(collator, operator, prev);

        _collect(collator, commission);
    }

    function stake(address collator, address oldPrev, address newPrev) public payable {
        require(exist(collator));
        address account = msg.sender;
        uint256 assets = msg.value;
        ICollatorStaking(collator).stake(account, assets);
        assetsOf[collator] += assets;
        _increaseScore(collator, _assetsToScore(collator, assets), oldPrev, newPrev);
        stakedRINGOf[account] += assets;
        emit Staked(collator, account, assets, oldPrev, newPrev);
    }

    function unstake(address collator, uint256 assets, address oldPrev, address newPrev) public {
        require(exist(collator));
        address account = msg.sender;
        ICollatorStaking(collator).withdraw(account, assets);
        assetsOf[collator] -= assets;
        payable(account).sendValue(assets);
        _reduceScore(collator, _assetsToScore(collator, assets), oldPrev, newPrev);
        stakedRINGOf[account] -= assets;
        emit Unstaked(collator, account, assets, oldPrev, newPrev);
    }

    function stakeNFT(address collator, uint256 depositId, address oldPrev, address newPrev) public {
        require(exist(collator));
        address account = msg.sender;
        DEPOSIT.transferFrom(account, address(this), depositId);
        uint256 assets = DEPOSIT.assetsOf(depositId);
        ICollatorStaking(collator).stake(account, assets);
        depositInfoOf[depositId] = DepositInfo(account, assets, collator);
        assetsOf[collator] += assets;
        _increaseScore(collator, _assetsToScore(collator, assets), oldPrev, newPrev);
        require(_stakedDepositsOf[account].add(depositId));
        emit Staked(collator, account, depositId, oldPrev, newPrev);
    }

    function unstakeNFT(uint256 depositId, address oldPrev, address newPrev) public {
        address account = msg.sender;
        DepositInfo memory info = depositInfoOf[depositId];
        require(exist(info.collator));
        require(info.account == account);
        ICollatorStaking(info.collator).withdraw(account, info.assets);
        DEPOSIT.transferFrom(address(this), account, depositId);
        delete depositInfoOf[depositId];
        assetsOf[info.collator] -= info.assets;
        _reduceScore(info.collator, _assetsToScore(info.collator, info.assets), oldPrev, newPrev);
        require(_stakedDepositsOf[account].remove(depositId));
        emit Unstaked(info.collator, info.account, depositId, oldPrev, newPrev);
    }

    function claim(address collator) public {
        require(exist(collator));
        ICollatorStaking(collator).getReward(msg.sender);
    }

    function distributeReward(address collator) public payable {
        require(exist(collator));
        require(msg.sender == STAKING_PALLET);
        uint256 rewards = msg.value;
        uint256 commission_ = rewards * commissionOf[collator] / COMMISSION_BASE;
        address operator = ICollatorStaking(collator).operator();
        payable(operator).sendValue(commission_);
        ICollatorStaking(collator).notifyRewardAmount{value: rewards - commission_}();
    }

    function collect(uint256 commission, address oldPrev, address newPrev) public {
        address collator = collatorOf[msg.sender];
        require(exist(collator));
        _removeCollator(collator, oldPrev);
        _collect(collator, commission);
        uint256 assets = assetsOf[collator];
        _addCollator(collator, _assetsToScore(collator, assets), newPrev);
    }

    function _collect(address collator, uint256 commission) internal {
        require(commission <= COMMISSION_BASE);
        commissionOf[collator] = commission;
        emit CommissionUpdated(collator, commission);
    }

    function _assetsToScore(address collator, uint256 assets) internal view returns (uint256) {
        uint256 commission = commissionOf[collator];
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
