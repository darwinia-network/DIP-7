// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../deposit/interfaces/IDeposit.sol";

contract GovernanceRing is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Address for address payable;
    using EnumerableSet for EnumerableSet.UintSet;

    // depositId => user
    mapping(uint256 => address) public depositorOf;
    // user => token => assets
    mapping(address => mapping(address => uint256)) public wrapAssets;
    // user => wrap depositIds
    mapping(address => EnumerableSet.UintSet) private _wrapDeposits;
    IDeposit public DEPOSIT;

    address public constant RING = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    event Wrap(address indexed account, address indexed token, uint256 assets);
    event Unwrap(address indexed account, address indexed token, uint256 assets);
    event WrapDeposit(address indexed account, address indexed token, uint256 depositId);
    event UnwrapDeposit(address indexed account, address indexed token, uint256 depositId);

    function initialize(address admin, address dps, string memory name, string memory symbol) public initializer {
        DEPOSIT = IDeposit(dps);
        __ERC20_init(name, symbol);
        __AccessControl_init();
        __ERC20Permit_init(symbol);
        __ERC20Votes_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function mint(address to, uint256 assets) public onlyRole(MINTER_ROLE) {
        _mint(to, assets);
    }

    function burn(address from, uint256 assets) public onlyRole(BURNER_ROLE) {
        _burn(from, assets);
    }

    function _wrap(address account, address token, uint256 assets) internal {
        _mint(account, assets);
        wrapAssets[account][token] += assets;
        emit Wrap(account, token, assets);
    }

    function _unwrap(address account, address token, uint256 assets) internal {
        _burn(account, assets);
        wrapAssets[account][token] -= assets;
        emit Unwrap(account, token, assets);
    }

    function wrapRING() public payable nonReentrant {
        _wrap(msg.sender, RING, msg.value);
    }

    function unwrapRING(uint256 assets) public nonReentrant {
        _unwrap(msg.sender, RING, assets);
        payable(msg.sender).sendValue(assets);
    }

    function wrapDeposit(uint256 depositId) public nonReentrant {
        address account = msg.sender;
        DEPOSIT.transferFrom(account, address(this), depositId);
        uint256 assets = DEPOSIT.assetsOf(depositId);
        depositorOf[depositId] = account;
        require(_wrapDeposits[account].add(depositId), "!add");
        _wrap(account, address(DEPOSIT), assets);
        emit WrapDeposit(account, address(DEPOSIT), assets);
    }

    function unwrapDeposit(uint256 depositId) public nonReentrant {
        address account = msg.sender;
        require(depositorOf[depositId] == account, "!account");
        uint256 assets = DEPOSIT.assetsOf(depositId);
        _unwrap(account, address(DEPOSIT), assets);
        require(_wrapDeposits[account].remove(depositId), "!remove");
        DEPOSIT.transferFrom(address(this), account, depositId);
        emit UnwrapDeposit(account, address(DEPOSIT), depositId);
    }

    function wrapDepositsOf(address account) public view returns (uint256[] memory) {
        return _wrapDeposits[account].values();
    }

    function wrapDepositsLength(address account) public view returns (uint256) {
        return _wrapDeposits[account].length();
    }

    function wrapDepositsAt(address account, uint256 index) public view returns (uint256) {
        return _wrapDeposits[account].at(index);
    }

    function wrapDepositsContains(address account, uint256 depositId) public view returns (bool) {
        return _wrapDeposits[account].contains(depositId);
    }

    function transfer(address, uint256) public override returns (bool) {
        revert();
    }

    function transferFrom(address, address, uint256) public override returns (bool) {
        revert();
    }

    function approve(address, uint256) public override returns (bool) {
        revert();
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }
}
