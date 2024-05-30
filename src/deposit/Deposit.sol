// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts@5.0.2/utils/Address.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721Burnable.sol";
import "./interfaces/IKTON.sol";

contract Deposit is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable {
    using Address for address payable;

    struct DepositInfo {
        uint64 months;
        uint64 startAt;
        uint128 value;
    }

    uint256 public count;
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

    constructor() ERC721("Deposit Token", "DPS") {}

    function migrate(address account, uint64 months, uint64 startAt) external payable onlySystem {
        uint256 value = msg.value;
        require(value > 0 && value < type(uint128).max, "!value");
        require(months <= 36 && months >= 1, "!months");
        require(startAt <= block.timestamp, "!startAt");

        uint256 id = count++;
        depositOf[id] = DepositInfo({months: months, startAt: startAt, value: uint128(value)});
        _safeMint(account, id);

        emit DepositMigrated(id, account, value, months, startAt);
    }

    function deposit(uint64 months) external payable {
        _deposit(msg.sender, msg.value, months);
    }

    function claim(uint256 depositId) external {
        DepositInfo memory info = depositOf[depositId];
        require(block.timestamp - info.startAt >= info.months * MONTH, "penalty");
        _claim(msg.sender, depositId, info.value);
    }

    function claimWithPenalty(uint256 depositId) public {
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

    function computeInterest(uint256 value, uint256 months) public pure returns (uint256) {
        // TODO: check
        uint64 unitInterest = 1_000;

        // these two actually mean the multiplier is 1.015
        uint256 numerator = 67 ** months;
        uint256 denominator = 66 ** months;
        uint256 quotient = numerator / denominator;
        uint256 remainder = numerator % denominator;

        // (quotient - 1) * 1000 === 0 (1 <= mouths <= 12) ?

        // depositing X RING for 12 months, interest is about (1 * unitInterest * X / 10**7) KTON
        // and the multiplier is about 3
        // ((quotient - 1) * 1000 + remainder * 1000 / denominator) is 197 when _month is 12.
        return (unitInterest * value) * ((quotient - 1) * 1000 + remainder * 1000 / denominator) / (197 * 10 ** 7);
    }

    function isClaimRequirePenalty(uint256 id) public view returns (bool) {
        return block.timestamp - depositOf[id].startAt < depositOf[id].months * MONTH;
    }

    function computePenalty(uint256 id) public view returns (uint256) {
        DepositInfo memory info = depositOf[id];

        uint256 monthsDuration = (block.timestamp - info.startAt) / MONTH;

        // TODO: check
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
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
