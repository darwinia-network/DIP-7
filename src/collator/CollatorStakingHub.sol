// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/INominationPool.sol";
import "./interfaces/IGRING.sol";
import "../deposit/interfaces/IDeposit.sol";
import "./NominationPool.sol";
import "./CollatorSet.sol";

contract CollatorStakingHub is ReentrancyGuardUpgradeable, CollatorSet {
    using Strings for uint256;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.UintSet;

    // The lock-up period starts with the stake or inscrease stake.
    uint256 public constant STAKING_LOCK_PERIOD = 1 days;
    // The lock-up period starts with the collator commsission update;
    uint256 public constant COMMISSION_LOCK_PERIOD = 7 days;
    // System Account.
    address public constant SYSTEM_PALLET = 0x6D6f646c64612f74727372790000000000000000;
    // 0 ~ 100
    uint256 private constant COMMISSION_BASE = 100;

    event Staked(address indexed pool, address collator, address account, uint256 assets);
    event Unstaked(address indexed pool, address collator, address account, uint256 assets);
    event NominationPoolCreated(address indexed pool, address collator);
    event CommissionUpdated(address indexed collator, uint256 commission);
    event RewardDistributed(address indexed collator, uint256 reward);

    modifier onlySystem() {
        require(msg.sender == SYSTEM_PALLET, "!system");
        _;
    }

    function initialize(address gring, address dps) public initializer {
        gRING = gring;
        DEPOSIT = dps;
        __ReentrancyGuard_init();
        __CollatorSet_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// 1. Create nomination pool
    /// 2. Join collator set
    /// 3. Set commsission
    function createAndCollate(address prev, uint256 commission) public returns (address pool) {
        address collator = msg.sender;
        pool = createNominationPool();
        _updateCommissionAndLock(collator, commission);
        _addCollator(collator, 0, prev);
    }

    /// 1. Join collator set
    /// 2. Set commission
    function collate(address prev, uint256 commission) public {
        address collator = msg.sender;
        require(poolOf[collator] != address(0), "!pool");
        _updateCommissionAndLock(collator, commission);
        _addCollator(collator, _assetsToVotes(commission, stakedOf(collator)), prev);
    }

    /// 1. Exit collator set
    /// 2. Clear commission
    function stopCollation(address prev) public {
        address collator = msg.sender;
        require(poolOf[collator] != address(0), "!pool");
        _setCommisson(collator, 0);
        _removeCollator(collator, prev);
    }

    function createNominationPool() public returns (address pool) {
        address collator = msg.sender;
        require(poolOf[collator] == address(0), "created");

        bytes memory bytecode = type(NominationPool).creationCode;
        bytes memory initCode = bytes.concat(bytecode, abi.encode(collator));
        assembly {
            pool := create2(0, add(initCode, 32), mload(initCode), 0)
        }
        require(pool != address(0), "!create2");
        poolOf[collator] = pool;
        emit NominationPoolCreated(pool, collator);
    }

    function updateCommission(uint256 commission, address oldPrev, address newPrev) public nonReentrant {
        address collator = msg.sender;
        require(poolOf[collator] != address(0), "!pool");
        require(commissionOf[collator] != commission, "same");
        _removeCollator(collator, oldPrev);
        _updateCommissionAndLock(collator, commission);
        _addCollator(collator, _assetsToVotes(commission, stakedOf(collator)), newPrev);
    }

    function _updateCommissionAndLock(address collator, uint256 commission) internal {
        require(commissionLocks[collator] < block.timestamp, "!locked");
        _setCommisson(collator, commission);
        commissionLocks[collator] = COMMISSION_LOCK_PERIOD + block.timestamp;
    }

    function _setCommisson(address collator, uint256 commission) internal {
        require(commission <= COMMISSION_BASE, "!commission");
        commissionOf[collator] = commission;
        emit CommissionUpdated(collator, commission);
    }

    function _updateCollatorVotes(address collator, address oldPrev, address newPrev) internal {
        uint256 assets = stakedOf(collator);
        uint256 newVotes = _assetsToVotes(commissionOf[collator], assets);
        _updateVotes(collator, newVotes, oldPrev, newPrev);
    }

    function _stake(address collator, address account, uint256 assets) internal {
        stakingLocks[collator][account] = STAKING_LOCK_PERIOD + block.timestamp;
        address pool = poolOf[collator];
        require(pool != address(0), "!pool");
        INominationPool(pool).stake(account, assets);
        IGRING(gRING).mint(account, assets);
        emit Staked(pool, collator, account, assets);
    }

    function _unstake(address collator, address account, uint256 assets) internal {
        require(stakingLocks[collator][account] < block.timestamp, "!locked");
        address pool = poolOf[collator];
        require(pool != address(0), "!pool");
        IGRING(gRING).burn(account, assets);
        INominationPool(pool).withdraw(account, assets);
        emit Unstaked(pool, collator, account, assets);
    }

    function claim(address collator) public nonReentrant {
        address pool = poolOf[collator];
        require(pool != address(0), "!collator");
        INominationPool(pool).getReward(msg.sender);
    }

    function stakeRING(address collator, address oldPrev, address newPrev) public payable nonReentrant {
        _stake(collator, msg.sender, msg.value);
        _updateCollatorVotes(collator, oldPrev, newPrev);
        stakedRINGOf[collator][msg.sender] += msg.value;
    }

    function unstakeRING(address collator, uint256 assets, address oldPrev, address newPrev) public nonReentrant {
        _unstake(collator, msg.sender, assets);
        _updateCollatorVotes(collator, oldPrev, newPrev);
        stakedRINGOf[collator][msg.sender] -= assets;
        payable(msg.sender).sendValue(assets);
    }

    function unstakeRINGFromInactiveCollator(address collator, uint256 assets) public nonReentrant {
        require(_isInactiveCollator(collator), "active");
        _unstake(collator, msg.sender, assets);
        stakedRINGOf[collator][msg.sender] -= assets;
        payable(msg.sender).sendValue(assets);
    }

    function stakeDeposits(address collator, uint256[] calldata depositIds, address oldPrev, address newPrev)
        public
        nonReentrant
    {
        require(depositIds.length > 0, "!len");
        address account = msg.sender;
        uint256 totalAssets;
        for (uint256 i = 0; i < depositIds.length; i++) {
            uint256 depositId = depositIds[i];
            IDeposit(DEPOSIT).transferFrom(account, address(this), depositId);
            uint256 assets = IDeposit(DEPOSIT).assetsOf(depositId);
            depositInfos[depositId] = DepositInfo(account, assets, collator);
            require(_stakedDeposits[account].add(depositId), "!add");
            totalAssets += assets;
        }
        _stake(collator, account, totalAssets);
        _updateCollatorVotes(collator, oldPrev, newPrev);
    }

    function unstakeDeposits(address collator, uint256[] calldata depositIds, address oldPrev, address newPrev)
        public
        nonReentrant
    {
        require(depositIds.length > 0, "!len");
        address account = msg.sender;
        uint256 totalAssets;
        for (uint256 i = 0; i < depositIds.length; i++) {
            uint256 depositId = depositIds[i];
            DepositInfo memory info = depositInfos[depositId];
            require(info.account == account, "!account");
            require(info.collator == collator, "!collator");
            IDeposit(DEPOSIT).transferFrom(address(this), account, depositId);
            require(_stakedDeposits[account].remove(depositId), "!remove");
            delete depositInfos[depositId];
            totalAssets += info.assets;
        }
        _unstake(collator, account, totalAssets);
        _updateCollatorVotes(collator, oldPrev, newPrev);
    }

    function unstakeDepositsFromInactiveCollator(address collator, uint256[] calldata depositIds) public nonReentrant {
        require(_isInactiveCollator(collator), "active");
        require(depositIds.length > 0, "!len");
        address account = msg.sender;
        uint256 totalAssets;
        for (uint256 i = 0; i < depositIds.length; i++) {
            uint256 depositId = depositIds[i];
            DepositInfo memory info = depositInfos[depositId];
            require(info.account == account, "!account");
            require(info.collator == collator, "!collator");
            IDeposit(DEPOSIT).transferFrom(address(this), account, depositId);
            require(_stakedDeposits[account].remove(depositId), "!remove");
            delete depositInfos[depositId];
            totalAssets += info.assets;
        }
        _unstake(collator, account, totalAssets);
    }

    /// @dev Distribute collator reward from Staking Pallet Account.
    ///      The amount of the reward must be passed in via msg.value.
    /// @notice Only Staking Pallet Account could call this function.
    /// @param collator The collator address to distribute reward.
    function distributeReward(address collator) public payable onlySystem nonReentrant {
        address pool = poolOf[collator];
        require(pool != address(0), "!pool");
        uint256 rewards = msg.value;
        uint256 commission_ = rewards * commissionOf[collator] / COMMISSION_BASE;
        payable(collator).sendValue(commission_);
        INominationPool(pool).notifyRewardAmount{value: rewards - commission_}();
        emit RewardDistributed(collator, rewards);
    }

    function stakedOf(address collator) public view returns (uint256) {
        address pool = poolOf[collator];
        require(pool != address(0), "!pool");
        return INominationPool(pool).totalSupply();
    }

    function assetsToVotes(uint256 commission, uint256 assets) public pure returns (uint256) {
        return _assetsToVotes(commission, assets);
    }

    function _assetsToVotes(uint256 commission, uint256 assets) internal pure returns (uint256) {
        return assets * (COMMISSION_BASE - commission) / COMMISSION_BASE;
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
