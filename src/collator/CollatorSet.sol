// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract CollatorSet {
    // collator count;
    uint256 public count;
    // ordered collators.
    mapping(address => address) public collators;
    // collator => staked ring
    mapping(address => uint256) public assetsOf;

    address private constant HEAD = address(0x1);
    address private constant TAIL = address(0x2);

    constructor() {
        collators[HEAD] = collators[TAIL];
        collators[HEAD] = type(uint256).max;
    }

    function exist(address c) public view returns (bool) {
        return collators[c] != address(0) && c != HEAD;
    }

    function getTopCollators(uint256 k) public view returns (address[] memory) {
        address[] memory topCollators = new address[](k);
        uint256 len = count;
        if (len > k) len = k;
        address cur = collators[HEAD];
        for (uint256 i = 0; i < k; i++) {
            topCollators = cur;
            cur = collators[cur];
        }
        return topCollators;
    }

    function _addCollator(address cur, uint256 assets, address prev) internal {
        require(cur != address(0) && cur != HEAD && cur != TAIL, "!valid");
        address next = collators[prev];
        // No duplicate collator allowed.
        require(collators[cur] == address(0));
        // Next collaotr must in the list.
        require(next != address(0));
        require(_verifyIndex(prev, assets, next));
        collators[cur] = next;
        collators[prev] = cur;
        assetsOf[cur] = assets;
        count++;
    }

    function _removeCollator(address cur, address prev) internal {
        require(cur != address(0) && cur != HEAD && cur != TAIL, "!valid");
        require(collators[cur] != address(0));
        require(_isPrevCollator(cur, prev));
        collators[prev] = collators[cur];
        collators[cur] = address(0);
        assetsOf[cur] = 0;
        count--;
    }

    function _increaseAssets(address cur, uint256 assets, address oldPrev, address newPrev) internal {
        _updateAssets(cur, assetsOf[cur] + assets, oldPrev, newPrev);
    }

    function _reduceAssets(address cur, uint256 assets, address oldPrev, address newPrev) internal {
        _updateCollator(cur, assetsOf[cur] - assets, oldPrev, newPrev);
    }

    function _updateAssets(address cur, uint256 newAssets, address oldPrev, address newPrev) internal {
        require(cur != address(0) && cur != HEAD && cur != TAIL, "!valid");
        require(collators[cur] != address(0));
        require(collators[oldPrev] != address(0));
        require(collators[newPrev] != address(0));
        if (oldPrev == newPrev) {
            require(_isPrevCollator(cur, oldPrev));
            require(_verifyIndex(newPrev, newAssets, collators[cur]));
            assetsOf[cur] = newAssets;
        } else {
            _removeCollator(cur, oldPrev);
            _addCollator(cur, newAssets, newPrev);
        }
    }

    // prev >= cur >= next
    function _verifyIndex(address prev, uint256 newValue, address next) internal view returns (bool) {
        return assetsOf[prev] >= newValue && newValue >= assetsOf[next];
    }

    function _isPrevCollator(address c, address prev) internal view returns (bool) {
        return collators[prev] == c;
    }
}
