// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IKTON.sol";

contract Deposit is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Address for address payable;

    // https://github.com/darwinia-network/darwinia/blob/main/core/inflation/src/test.rs#L86C1-L103C2
    // precision = 10_000
    uint256[37] public INTERESTS = [
        0,
        761,
        1522,
        2335,
        3096,
        3959,
        4771,
        5634,
        6446,
        7309,
        8223,
        9086,
        10000,
        10913,
        11878,
        12842,
        13807,
        14771,
        15736,
        16751,
        17766,
        18832,
        19898,
        20964,
        22030,
        23147,
        24263,
        25380,
        26548,
        27715,
        28934,
        30101,
        31370,
        32588,
        33857,
        35126,
        36446
    ];

    uint256 public count;

    struct DepositInfo {
        uint64 months;
        uint64 startAt;
        uint128 value;
    }

    mapping(uint256 => DepositInfo) public depositOf;

    uint256 public constant MONTH = 30 days;
    // TODO:
    address public constant DEPOSIT_PALLET = address(0);
    IKTON public constant KTON = IKTON(0x0000000000000000000000000000000000000402);

    event DepositCreated(
        uint256 indexed depositId, address indexed account, uint256 value, uint256 months, uint256 interest
    );
    event DepositMigrated(
        uint256 indexed depositId, address indexed account, uint256 value, uint256 months, uint256 startAt
    );
    event DepositClaimed(uint256 indexed depositId, address indexed account, uint256 value);
    event ClaimWithPenalty(uint256 indexed depositId, address indexed account, uint256 penalty);

    modifier onlySystem() {
        require(msg.sender == DEPOSIT_PALLET);
        _;
    }

    function initialize(string memory name, string memory symbol) public initializer {
        __ERC721_init(name, symbol);
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ReentrancyGuard_init();
    }

    constructor() {
        _disableInitializers();
    }

    function migrate(address account, uint64 months, uint64 startAt) external payable onlySystem nonReentrant {
        uint256 value = msg.value;
        require(value > 0 && value < type(uint128).max, "!value");
        require(months <= 36 && months >= 1, "!months");
        require(startAt <= block.timestamp, "!startAt");

        uint256 id = count++;
        depositOf[id] = DepositInfo({months: months, startAt: startAt, value: uint128(value)});
        _safeMint(account, id);

        emit DepositMigrated(id, account, value, months, startAt);
    }

    function deposit(uint64 months) external payable nonReentrant {
        _deposit(msg.sender, msg.value, months);
    }

    function claim(uint256 depositId) external nonReentrant {
        DepositInfo memory info = depositOf[depositId];
        require(block.timestamp - info.startAt >= info.months * MONTH, "penalty");
        _claim(msg.sender, depositId, info.value);
    }

    function claimWithPenalty(uint256 depositId) public nonReentrant {
        uint256 penalty = computePenalty(depositId);
        require(KTON.burn(address(this), penalty));

        DepositInfo memory info = depositOf[depositId];
        require(block.timestamp - info.startAt < info.months * MONTH, "!penalty");
        _claim(msg.sender, depositId, info.value);

        emit ClaimWithPenalty(depositId, msg.sender, penalty);
    }

    function assetsOf(uint256 id) public view returns (uint256) {
        return depositOf[id].value;
    }

    function _deposit(address account, uint256 value, uint64 months) internal returns (uint256) {
        require(value > 0 && value < type(uint128).max);
        require(months <= 36 && months >= 1);

        uint256 id = count++;
        depositOf[id] = DepositInfo({months: months, startAt: uint64(block.timestamp), value: uint128(value)});

        uint256 interest = computeInterest(value, months);
        require(KTON.mint(account, interest));
        _safeMint(account, id);

        emit DepositCreated(id, account, value, months, interest);
        return id;
    }

    function computeInterest(uint256 value, uint256 months) public view returns (uint256) {
        uint256 interest = INTERESTS[months];
        return value * interest / 10_000;
    }

    function isClaimRequirePenalty(uint256 id) public view returns (bool) {
        return block.timestamp - depositOf[id].startAt < depositOf[id].months * MONTH;
    }

    function computePenalty(uint256 id) public view returns (uint256) {
        DepositInfo memory info = depositOf[id];

        uint256 monthsDuration = (block.timestamp - info.startAt) / MONTH;

        return 3 * (computeInterest(info.value, info.months) - computeInterest(info.value, monthsDuration));
    }

    function _claim(address account, uint256 id, uint256 value) internal {
        require(_requireOwned(id) == account, "!owned");

        _burn(id);
        delete depositOf[id];
        payable(account).sendValue(value);

        emit DepositClaimed(id, account, value);
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
