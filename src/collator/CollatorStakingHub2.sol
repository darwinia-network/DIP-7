// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract CollatorStakingHub {
    // Deposit NFT.
    address nft;

    address stakingPallet;

    address public gRING;

    // ordered collators.
    address[] public collators;

    // collator operator => collator
    mapping(address => address) public collatorOf;

    uint256 private constant COMMISSION_BASE = 10_000;

    // collator => commission
    mapping(address => uint256) commissionOf;

    struct DepositInfo {
        address usr;
        uint256 assets;
        address collator;
    }

    mapping(uint256 => DepositInfo) public depositOf;

    function _reOrder() internal {
        collators.DescByTotalSupply();
    }

    function createCollator() public {
        address operator = msg.sender;
        CollatorStaking collator = new CollatorStaking(operator, wring);
        require(collators.add(collator));
        collatorOf[operator] = collator;
        _reOrder();
    }

    function stake(address operator) public payable {
        address usr = msg.sender;
        CollatorStaking collator = collatorOf[operator];
        collator.stake(msg.value, usr);
        gRING.mint(usr, msg.value);
        _reOrder();
    }

    function unstake(uint256 amount, address operator) public {
        address usr = msg.sender;
        CollatorStaking collator = collatorOf[operator];
        collator.withdraw(amount, usr);
        usr.transfer(amount);
        gRING.burn(usr, amount);
        _reOrder();
    }

    function claim(address operator) public {
        address usr = msg.sender;
        CollatorStaking collator = collatorOf[operator];
        collator.getReward(usr);
    }

    function stakeNFT(uint256 depositId, address operator) public {
        address usr = msg.sender;
        nft.transferFrom(usr, address(this), depositId);
        uint256 assets = nft.assetsOf(depositId);
        CollatorStaking collator = collatorOf[operator];
        collator.stake(assets, usr);
        depositOf[depositId] = DepositInfo(usr, assets, collator);
        gRING.mint(usr, assets);
        _reOrder();
    }

    function unstakeNFT(uint256 depositId) public {
        address usr = msg.sender;
        DepositInfo memory info = depositOf[depositId];
        require(info.usr == usr);
        info.collator.withdraw(info.assets, usr);
        nft.transferFrom(address(this), usr, depositId);
        gRING.burn(usr, info.assets);
        _reOrder();
    }

    function getTopCollators(uint256 count) public view returns (address[] memory) {
        address[] memory topCollators = new address[](count);
        uint256 len = collators.length;
        if (len > count) len = count;
        for (uint256 i = 0; i < count; i++) {
            topCollators = collators[i];
        }
        return topCollators;
    }

    function distributeReward(address collator) public payable {
        require(msg.sender == stakingPallet);
        uint256 rewards = msg.value;
        uint256 commission_ = rewards * commissionOf[collator] / COMMISSION_BASE;
        address operator = collator.operator();
        operator.transfer(commission_);
        collator.notifyRewardAmount{value: rewards - commission_}();
    }

    function collect(uint256 commission, address collator) public {
        require(commission <= COMMISSION_BASE);
        require(msg.sender == collator.operator());
        commissionOf[collator] = commission;
    }
}
