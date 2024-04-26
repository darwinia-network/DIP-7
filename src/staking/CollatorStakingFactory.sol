// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@4.9.6/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts@4.9.6/utils/Strings.sol";
import "./CollatorStaking.sol";

contract CollatorStakingFactory {
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _collators;

    // deposit NFT;
    address public nft;

    // creator => collator
    mapping(address => address) public collatorOf;

    event NewCollator();

    constructor(address nft_) {
        nft = nft_;
    }

    function createCollator() public {
        address creator = msg.sender;
        require(collatorOf[user] == address(0));
        string memory index = _collators.length().toString();
        CollatorStaking collator = new CollatorStaking(creator, nft);
        StRING stRing =
            new StRING(collator, string.concat("Darwinia Staked RING-", index), string.concat("stRING-", index));
        StNFT stNFT =
            new StNFT(collator, string.concat("Darwinia Staked Deposit RING-", index), string.concat("stDRING-", index));
        collator.initialize(stRing, stNFT);
        require(_collators.add(collator));
        collatorOf[creator] = collator;
        emit NewCollator();
    }
}
