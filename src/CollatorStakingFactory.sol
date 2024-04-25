// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@4.9.6/utils/structs/EnumerableSet.sol";
import "./CollatorStaking.sol";

contract CollatorStakingFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private collators;

    // deposit NFT;
    address public nft;

    // creator => collator
    mapping(address => address) public collatorOf;

    event NewCollator();
    event Deposit();
    event Withdraw();

    constructor() {
        nft = new StDeposit();
    }

    function createCollator() public nonreentrant {
        address creator = msg.sender;
        require(collatorOf[user] == address(0));
        STRING stRing = new STRING();
        STNFT stNFT = new STNFT();
        CollatorStaking collator = new CollatorStaking(creator, stRING, stNFT);
        require(collators.add(collator));
        collatorOf[creator] = collator;
        emit NewCollator();
    }

    function deposit() external payable nonreentrant {
        require(msg.value > 0);
        nft.mint(msg.sender, msg.value);

        emit Deposit();
    }

    function redeem(uint256 nftId) external nonreentrant {
        uint256 shares = nft.sharesOf[nftId];
        nft.burn(nftId);
        msg.sender.call{value: shares}();
        emit Withdraw();
    }
}
