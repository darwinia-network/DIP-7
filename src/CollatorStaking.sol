// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// TODO:: how to elect top collators?
contract CollatorStaking {
    enum Rounding {
        ROUND_DOWN,
        ROUND_UP
    }

    address creator;

    // assert nft
    IERC721 nft;
    // assert ft(ring) + assert nft
    uint256 totalAssets;

    // share ft
    IERC20 stRING;
    // share nft
    IERC721 stNFT;
    // share ft + share nft
    uint256 totalShares;

    event Deposit(address recipient, uint256 assets, uint256 shares);
    event DepositNFT(address recipient, uint256 assets, uint256 shares);
    event Withdraw(address sender, uint256 assets, uint256 shares);
    event WithdrawNFT(address sender, uint256 assets, uint256 shares);

    constructor(address creator_, address stRING_, address stNFT_) {
        creator = creator_;
        stRING = stRING_;
        stNFT = stNFT_;
    }

    receive() payable nonreentrant {
        uint256 assets = msg.value;
        require(assets > 0);
        totalAssets += assets;
    }

    function depositFT() external payable nonreentrant {
        uint256 assets = msg.value;
        address recipient = msg.sender;
        require(assets > 0);

        uint256 shares = _issueSharesForAmount(assets, recipient, false);

        totalAssets += assets;

        require(shares > 0);

        totalPowers += assets;

        emit Deposit(recipient, assets, shares);
    }

    function redeem(uint256 shares) external nonreentrant {
        uint256 assets = _convert_to_assets(shares, Rounding.ROUND_DOWN);
        require(shares > 0 && assets > 0);
        _burnShares(shares, msg.sender);
        totalAssets -= assets;
        msg.sender.call{value: assets}();

        emit Withdraw(msg.sender, assets, shares);
    }

    function redeemNFT(uint256 nftId) external nonreentrant {
        uint256 shares = stNFT.sharesOf(nftId);
        uint256 assets = _convert_to_assets(shares, Rounding.ROUND_DOWN);
        require(shares > 0 && assets > 0);
        _burnNFTShares(shares, nftId);
        totalAssets -= assets;
        msg.sender.call{value: assets}();
    }

    function depositNFT(uint256 nftId) external nonreentrant {
        uint256 assets = nft.assetOf(nftId);
        address recipient = msg.sender;
        nft.transferFrom(msg.sender, address(this), nftId);

        uint256 shares = _issueSharesForAmount(assets, recipient, true);

        totalPowers += assets;
        emit DepositNFT(recipient, assets, shares);
    }

    function _issueSharesForAmount(uint256 amount, address recipient, bool isNFT)
        internal
        returns (uint256 newShares)
    {
        if (totalShares == 0) {
            newShares = amount;
        } else {
            newShares = amount * totalShares / totalAssets;
        }

        if (newShares == 0) {
            return 0;
        }

        if (isNFT) {
            _issueNFTShares(newShares, recipient);
        } else {
            _issueShares(newShares, recipient);
        }
    }

    function _issueShares(uint256 shares, address recipient) internal {
        stRING.mint(recipient, shares);
        totalShares += shares;
    }

    function _burnShares(uint256 shares, address from) internal {
        stRING.burn(from, shares);
        totalShares -= shares;
    }

    function _issueNFTShares(uint256 shares, address recipient) internal {
        stNFT.mint(recipient, shares);
        totalShares += shares;
    }

    function _burnNFTShares(uint256 shares, address from, uint256 nftId) internal {
        stNFT.burn(from, nftId);
        totalShares -= shares;
    }

    // assets = shares * (total_assets / total_supply) --- (== price_per_share * shares)
    function _convert_to_assets(uint256 shares, Rounding rounding) internal view returns (uint256) {
        require(shares > 0 && totalShares > 0);
        uint256 numerator = shares * totalAssets;
        uint256 assets = numerator / totalShares;

        if (rounding == Rounding.ROUND_UP && numerator % totalShares != 0) {
            assets += 1;
        }
        return assets;
    }

    // shares = amount * (total_supply / total_assets) --- (== amount / price_per_share)
    function _convert_to_shares(uint256 assets, Rounding rounding) internal view returns (uint256) {
        require(assets > 0 && totalAssets > 0);
        uint256 numerator = assets * totalShares;
        uint256 shares = numerator / totalAssets;
        if (rounding == Rounding.ROUND_UP && numerator % totalAssets != 0) {
            shares += 1;
        }
        return shares;
    }
}
