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

    constructor(address nft_) {
        nft = nft_;
    }

    function createCollator() public nonreentrant {
        address creator = msg.sender;
        require(collatorOf[user] == address(0));
        STRING stRing = new STRING();
        STNFT stNFT = new STNFT();
        CollatorStaking collator = new CollatorStaking(creator, nft, stRING, stNFT);
        require(collators.add(collator));
        collatorOf[creator] = collator;
        emit NewCollator();
    }
}
