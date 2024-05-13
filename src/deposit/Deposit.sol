// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts@5.0.2/utils/Address.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@5.0.2/utils/cryptography/EIP712.sol";

contract Deposit is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable {
    using Address for address payable;

    struct DepositInfo {
        uint48 months;
        uint48 startAt;
        uint128 value;
    }

    address public depositPallet;

    uint256 public depositCount;
    mapping(uint256 => DepositInfo) public depositOf;

    uint256 public constant MONTH = 30 days;
    IERC20 public constant KTON = IERC20(0x0000000000000000000000000000000000000402);

    event NewDeposit(uint256 indexed depositId, address indexed owner, uint256 value, uint256 months, uint256 interest);
    event ClaimedDeposit(
        uint256 indexed depositId, address indexed owner, uint256 value, bool isPenalty, uint256 penaltyAmount
    );

    modifier onlySystem() {
        require(msg.sender == depositPallet);
        _;
    }

    constructor() ERC721("Deposit Token", "DPS") EIP712("Deposit Token", "1") {}

    function migrate(address account, uint48 months) external payable onlySystem {
        _deposit(account, msg.value, months);
    }

    function deposit(uint48 months) external payable {
        _deposit(msg.sender, msg.value, months);
    }

    function depositFor(address account, uint48 months) external payable {
        _deposit(account, msg.value, months);
    }

    function claim(uint256 depositId) external {
        _claim(msg.sender, depositId, false, 0);
    }

    function claimWithPenalty(uint256 depositId) public {
        uint256 penalty = computePenalty(depositId);

        require(KTON.transferFrom(msg.sender, address(this), penalty));

        _claim(msg.sender, depositId, true, penalty);

        KTON.burn(address(this), penalty);
    }

    function assetsOf(uint256 id) public view returns (uint256) {
        return depositOf[id].value;
    }

    function _deposit(address account, uint256 value, uint48 months) internal returns (uint256) {
        require(value > 0 && value < type(uint128).max);
        require(months <= 36 && months >= 1);

        uint256 id = depositCount++;
        depositOf[id] = DepositInfo({months: months, startAt: uint48(block.timestamp), value: uint128(value)});

        uint256 interest = computeInterest(value, months);
        KTON.mint(account, interest);
        _safeMint(account, id);

        emit NewDeposit(id, account, value, months, interest);
        return id;
    }

    function computeInterest(uint256 value, uint48 months) public pure returns (uint256) {
        // TODO:
        uint64 unitInterest = 1_000;

        // these two actually mean the multiplier is 1.015
        uint256 numerator = 67 ** months;
        uint256 denominator = 66 ** months;
        uint256 quotient = numerator / denominator;
        uint256 remainder = numerator % denominator;

        // depositing X RING for 12 months, interest is about (1 * unitInterest * X / 10**7) KTON
        // and the multiplier is about 3
        // ((quotient - 1) * 1000 + remainder * 1000 / denominator) is 197 when _month is 12.
        return (unitInterest * value) * ((quotient - 1) * 1000 + remainder * 1000 / denominator) / (197 * 10 ** 7);
    }

    function isClaimRequirePenalty(uint256 id) public view {
        return depositOf[id].startAt > 0 && block.timestamp - depositOf[id].startAt < depositOf[id].months * MONTH;
    }

    function computePenalty(uint256 id) public view returns (uint256) {
        require(isClaimRequirePenalty(id), "Claim do not need Penalty.");

        DepositInfo memory info = depositOf[id];

        uint256 monthsDuration = (block.timestamp - info.startAt) / MONTH;

        // TODO:
        uint256 penalty = 3 * (computeInterest(info.value, info.months) - computeInterest(info.value, monthsDuration));

        return penalty;
    }

    function _claim(address account, uint256 id, bool isPenalty, uint256 penaltyAmount) internal {
        require(_requireOwned(id));

        DepositInfo memory info = depositOf[id];

        if (isPenalty) {
            require(block.timestamp - info.startAt < info.months * MONTH);
        } else {
            require(block.timestamp - info.startAt >= info.months * MONTH);
        }

        payable(account).sendValue(info.value);

        emit ClaimedDeposit(id, account, info.value, isPenalty, penaltyAmount);

        _burn(id);
        delete depositOf[id];
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
