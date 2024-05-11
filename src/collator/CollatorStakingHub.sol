// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./CollatorSet.sol";

contract CollatorStakingHub is CollatorSet {
    // Deposit NFT.
    address public nft;

    address public stakingPallet;

    // operator => collator
    mapping(address => address) public collatorOf;

    // collator => commission
    mapping(address => uint256) public commissionOf;

    struct DepositInfo {
        address usr;
        uint256 assets;
        address collator;
    }

    // depositId => depositInfo
    mapping(uint256 => DepositInfo) public depositOf;
    // depositor => staked ring
    mapping(address => uint256) public stakedOf;

    uint256 private constant COMMISSION_BASE = 10_000;

    constructor() CollatorSet() {}

    function createCollator(address prev, uint256 commission) public {
        address operator = msg.sender;
        require(collatorOf[operator] == address(0));
        CollatorStaking cur = new CollatorStaking(operator);
        collatorOf[operator] = collator;
        _addCollator(collator, 0, prev);
    }

    function stake(address operator, address oldPrev, address newPrev) public payable {
        address account = msg.sender;
        uint256 amount = msg.value;
        CollatorStaking collator = collatorOf[operator];
        collator.stake(account, amount);
        _increaseFund(collator, amount, oldPrev, newPrev);
        stakedOf[account] += amount;
    }

    function unstake(address operator, uint256 amount, address oldPrev, address newPrev) public {
        address usr = msg.sender;
        CollatorStaking collator = collatorOf[operator];
        collator.withdraw(usr, amount);
        usr.transfer(amount);
        _reduceFund(collator, amount, oldPrev, newPrev);
        stakedOf[account] -= amount;
    }

    function claim(address operator) public {
        address usr = msg.sender;
        CollatorStaking collator = collatorOf[operator];
        collator.getReward(usr);
    }

    function stakeNFT(address operator, uint256 depositId, address oldPrev, address newPrev) public {
        address usr = msg.sender;
        nft.transferFrom(usr, address(this), depositId);
        uint256 assets = nft.assetsOf(depositId);
        CollatorStaking collator = collatorOf[operator];
        collator.stake(usr, assets);
        depositOf[depositId] = DepositInfo(usr, assets, collator);
        _increaseFund(collator, amount, oldPrev, newPrev);
    }

    function unstakeNFT(uint256 depositId, address oldPrev, address newPrev) public {
        address usr = msg.sender;
        DepositInfo memory info = depositOf[depositId];
        require(info.usr == usr);
        info.collator.withdraw(usr, info.assets);
        nft.transferFrom(address(this), usr, depositId);
        _reduceFund(collator, amount, oldPrev, newPrev);
    }

    function distributeReward(address collator) public payable {
        require(msg.sender == stakingPallet);
        uint256 rewards = msg.value;
        uint256 commission_ = rewards * commissionOf[collator] / COMMISSION_BASE;
        address operator = collator.operator();
        operator.transfer(commission_);
        collator.notifyRewardAmount{value: rewards - commission_}();
    }

    function collect(uint256 commission) public {
        CollatorStaking collator = collatorOf[msg.sender];
        _collect(collator, commission);
    }

    function _collect(address collator, uint256 commission) internal {
        require(commission <= COMMISSION_BASE);
        commissionOf[collator] = commission;
    }
}
