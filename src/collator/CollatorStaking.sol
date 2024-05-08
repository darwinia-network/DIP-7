// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@4.9.6/utils/math/Math.sol";

contract CollatorStaking {
    using Math for uint256;

    address public hub;
    address public operator;

    uint256 public totalAssets;
    uint256 public totalShares;

    mapping(address => uint256) sharesOf;

    modifier onlyHub() {
        require(msg.sender == hub);
        _;
    }

    constructor(address operator_) {
        hub = msg.sender;
        operator = operator_;
    }

    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    function stake(uint256 assets, address recipient) external onlyHub returns (uint256) {
        uint256 shares = previewDeposit(assets);

        sharesOf[receiver] = shares;
        totalShares += shares;
        emit Deposit(receiver, assets, shares);

        return shares;
    }

    function unstake(uint256 shares, address from) external onlyHub returns (uint256) {
        uint256 assets = previewRedeem(shares);

        sharesOf[from] -= shares;
        totalShares -= shares;
        emit Withdraw(from, assets, shares);

        return assets;
    }

    function distributeReward(uint256 rewards) external onlyHub {
        totalAssets += rewards;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    // assets = shares * (total_assets / total_shares) --- (== price_per_share * shares)
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    // shares = amount * (total_shares / total_assets) --- (== amount / price_per_share)
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    function _decimalsOffset() internal view returns (uint8) {
        return 8;
    }

    function decimals() public view returns (uint8) {
        return 18 + _decimalsOffset();
    }
}
