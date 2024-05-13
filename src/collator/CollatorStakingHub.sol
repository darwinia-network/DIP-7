// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@5.0.2/utils/Strings.sol";
import "@openzeppelin/contracts@5.0.2/utils/Address.sol";
import "@openzeppelin/contracts@5.0.2/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/IERC721.sol";
import "./interfaces/ICollatorStaking.sol";
import "./CollatorStaking.sol";
import "./CollatorSet.sol";

contract CollatorStakingHub is CollatorSet {
    using Strings for uint256;
    using Address for address;
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

    // depositId => depositInfo
    mapping(uint256 => DepositInfo) public depositInfoOf;
    // depositor => staked ring
    mapping(address => uint256) public stakedRINGOf;
    // depositor => staked depositIds
    mapping(address => EnumerableSet.UintSet) private _stakedDepositsOf;

    // Deposit NFT.
    IERC721 public immutable DEPOSIT;
    // TODO:
    address public immutable STAKING_PALLET = address(0);

    uint256 private constant COMMISSION_BASE = 10_000;

    event CollatorCreated(address indexed collator, address operator, address prev);
    event RingStaked(address indexed collator, address account, uint256 assets, address oldPrev, address newPrev);
    event RingUnstaked(address indexed collator, address account, uint256 assets, address oldPrev, address newPrev);
    event DepositStaked(
        address indexed collaotr, address account, uint256 assets, uint256 depositId, address oldPrev, address newPrev
    );
    event DepositUnstaked(
        address indexed collaotr, address account, uint256 assets, uint256 depositId, address oldPrev, address newPrev
    );

    constructor(address dps) CollatorSet() {
        DEPOSIT = IERC721(dps);
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
    }

    function stake(address collator, address oldPrev, address newPrev) public payable {
        require(exist(collator));
        address account = msg.sender;
        uint256 assets = msg.value;
        ICollatorStaking(collator).stake(account, assets);
        _increaseAssets(collator, assets, oldPrev, newPrev);
        stakedRINGOf[account] += assets;
        emit RINGStaked(collator, account, assets, oldPrev, newPrev);
    }

    function unstake(address collator, uint256 assets, address oldPrev, address newPrev) public {
        require(exist(collator));
        address account = msg.sender;
        ICollatorStaking(collator).withdraw(account, assets);
        account.sendValue(assets);
        _reduceAssets(collator, assets, oldPrev, newPrev);
        require(stakedRINGOf[account] >= assets);
        stakedRINGOf[account] -= assets;
        emit RINGUnstaked(collator, account, assets, oldPrev, newPrev);
    }

    function stakeNFT(address collator, uint256 depositId, address oldPrev, address newPrev) public {
        require(exist(collator));
        address account = msg.sender;
        DEPOSIT.transferFrom(account, address(this), depositId);
        uint256 assets = DEPOSIT.assetsOf(depositId);
        ICollatorStaking(collator).stake(account, assets);
        depositInfoOf[depositId] = DepositInfo(account, assets, collator);
        _increaseAssets(collator, assets, oldPrev, newPrev);
        require(_stakedDepositsOf[account].add(depositId));
        emit DepositStaked(collaotr, account, assets, depositId, oldPrev, newPrev);
    }

    function unstakeNFT(uint256 depositId, address oldPrev, address newPrev) public {
        require(exist(collator));
        address account = msg.sender;
        DepositInfo memory info = depositInfoOf[depositId];
        require(info.account == account);
        ICollatorStaking(info.collator).withdraw(account, info.assets);
        DEPOSIT.transferFrom(address(this), account, depositId);
        delete depositInfoOf[depositId];
        _reduceFund(collator, info.assets, oldPrev, newPrev);
        require(_stakedDepositsOf[account].remove(depositId));
        emit DepositUnstaked(info.collator, info.account, info.assets, depositId, oldPre, newPrev);
    }

    function claim(address operator) public {
        address usr = msg.sender;
        CollatorStaking collator = collatorOf[operator];
        collator.getReward(usr);
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

    function stakedDepositsOf(address account) public view returns (address[] memory) {
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
