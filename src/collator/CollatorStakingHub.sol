// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/ICollatorStakingPool.sol";
import "./interfaces/IGRING.sol";
import "../deposit/interfaces/IDeposit.sol";
import "./CollatorStakingPool.sol";
import "./CollatorSet.sol";

contract CollatorStakingHub is Initializable, ReentrancyGuardUpgradeable, CollatorSet {
    using Strings for uint256;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.UintSet;

    // The lock-up period starts with the stake or inscrease stake.
    uint256 public constant LOCK_PERIOD = 1 days;
    // Staking Pallet Account.
    address public constant STAKING_PALLET = 0x6D6F646C64612f7374616B690000000000000000;
    // 0 ~ 100
    uint256 private constant COMMISSION_BASE = 100;

    event Staked(address indexed pool, address collator, address account, uint256 assets);
    event Unstaked(address indexed pool, address collator, address account, uint256 assets);
    event CollatorStakingPoolCreated(address indexed stRING, address collator, address prev);
    event CommissionUpdated(address indexed collator, uint256 commission);

    modifier onlySystem() {
        require(msg.sender == STAKING_PALLET, "!system");
        _;
    }

    function initialize(address gring, address dps, string memory symbol) public initializer {
        gRING = gring;
        DEPOSIT = dps;
        SYMBOL = symbol;
        __ReentrancyGuard_init();
        __CollatorSet_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function exist(address pool) public view returns (bool) {
        return collatorOf[pool] != address(0);
    }

    function createCollatorStakingPool(address prev, uint256 commission) public returns (address pool) {
        address collator = msg.sender;
        require(poolOf[collator] == address(0), "created");

        uint256 index = count;
        bytes memory bytecode = type(CollatorStakingPool).creationCode;
        bytes memory initCode = bytes.concat(bytecode, abi.encode(collator, index));
        assembly {
            pool := create2(0, add(initCode, 32), mload(initCode), 0)
        }
        require(pool != address(0), "!create2");
        require(collatorOf[pool] == address(0), "duplicate");

        poolOf[collator] = pool;
        collatorOf[pool] = collator;
        _addCollator(collator, 0, prev);
        _collect(collator, commission);
        emit CollatorStakingPoolCreated(pool, collator, prev);
    }

    function _stake(address collator, address account, uint256 assets) internal {
        stakingLocks[collator][account] = LOCK_PERIOD + block.timestamp;
        address pool = poolOf[collator];
        require(pool != address(0), "!collator");
        ICollatorStakingPool(pool).stake(account, assets);
        IGRING(gRING).mint(account, assets);
        emit Staked(pool, collator, account, assets);
    }

    function _unstake(address collator, address account, uint256 assets) internal {
        require(stakingLocks[collator][account] < block.timestamp, "!locked");
        address pool = poolOf[collator];
        require(pool != address(0), "!collator");
        IGRING(gRING).burn(account, assets);
        ICollatorStakingPool(pool).withdraw(account, assets);
        emit Unstaked(pool, collator, account, assets);
    }

    function claim(address collator) public nonReentrant {
        address pool = poolOf[collator];
        require(pool != address(0), "!collator");
        ICollatorStakingPool(pool).getReward(msg.sender);
    }

    function stakeRING(address collator, address oldPrev, address newPrev) public payable nonReentrant {
        _stake(collator, msg.sender, msg.value);
        _increaseVotes(collator, _assetsToVotes(commissionOf[collator], msg.value), oldPrev, newPrev);
        stakedRINGOf[msg.sender] += msg.value;
    }

    function unstakeRING(address collator, uint256 assets, address oldPrev, address newPrev) public nonReentrant {
        _unstake(collator, msg.sender, assets);
        payable(msg.sender).sendValue(assets);
        _reduceVotes(collator, _assetsToVotes(commissionOf[collator], assets), oldPrev, newPrev);
        stakedRINGOf[msg.sender] -= assets;
    }

    function stakeNFT(address collator, uint256 depositId, address oldPrev, address newPrev) public nonReentrant {
        address account = msg.sender;
        IDeposit(DEPOSIT).transferFrom(account, address(this), depositId);
        uint256 assets = IDeposit(DEPOSIT).assetsOf(depositId);
        depositInfos[depositId] = DepositInfo(account, assets, collator);

        _stake(collator, account, assets);
        _increaseVotes(collator, _assetsToVotes(commissionOf[collator], assets), oldPrev, newPrev);
        require(_stakedDeposits[account].add(depositId), "!add");
    }

    function unstakeNFT(uint256 depositId, address oldPrev, address newPrev) public nonReentrant {
        address account = msg.sender;
        DepositInfo memory info = depositInfos[depositId];
        require(info.account == account);
        IDeposit(DEPOSIT).transferFrom(address(this), account, depositId);
        delete depositInfos[depositId];

        _unstake(info.collator, info.account, info.assets);
        _reduceVotes(info.collator, _assetsToVotes(commissionOf[info.collator], info.assets), oldPrev, newPrev);
        require(_stakedDeposits[account].remove(depositId), "!remove");
    }

    function collect(uint256 commission, address oldPrev, address newPrev) public nonReentrant {
        address collator = msg.sender;
        require(poolOf[collator] != address(0), "!collator");
        _removeCollator(collator, oldPrev);
        _collect(collator, commission);
        _addCollator(collator, _assetsToVotes(commission, stakedOf(collator)), newPrev);
    }

    function distributeReward(address collator) public payable onlySystem nonReentrant {
        address pool = poolOf[collator];
        require(pool != address(0), "!collator");
        uint256 rewards = msg.value;
        uint256 commission_ = rewards * commissionOf[collator] / COMMISSION_BASE;
        payable(collator).sendValue(commission_);
        ICollatorStakingPool(pool).notifyRewardAmount{value: rewards - commission_}();
    }

    function stakedOf(address collator) public view returns (uint256) {
        return IERC20(collator).totalSupply();
    }

    function _collect(address collator, uint256 commission) internal {
        require(commission <= COMMISSION_BASE);
        commissionOf[collator] = commission;
        emit CommissionUpdated(collator, commission);
    }

    function _assetsToVotes(uint256 commission, uint256 assets) internal pure returns (uint256) {
        return assets * (100 - commission) / 100;
    }

    function stakedDepositsOf(address account) public view returns (uint256[] memory) {
        return _stakedDeposits[account].values();
    }

    function stakedDepositsLength(address account) public view returns (uint256) {
        return _stakedDeposits[account].length();
    }

    function stakedDepositsAt(address account, uint256 index) public view returns (uint256) {
        return _stakedDeposits[account].at(index);
    }

    function stakedDepositsContains(address account, uint256 depositId) public view returns (bool) {
        return _stakedDeposits[account].contains(depositId);
    }
}
