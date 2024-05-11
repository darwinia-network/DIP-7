// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract CollatorSet {
    // collator count;
    uint256 public count;
    // ordered collators.
    mapping(address => address) public collators;
    // collator => staked ring
    mapping(address => uint256) public fundOf;

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

    function _addCollator(address cur, uint256 fund, address prev) internal {
        require(collators[cur] == address(0));
        require(collators[prev] != address(0));
        address next = collators[prev];
        require(_verifyIndex(prev, fund, next));
        fundOf[cur] = fund;
        collators[cur] = next;
        collators[prev] = cur;
        count++;
    }

    function _removeCollator(address cur, address prev) internal {
        require(collators[cur] != address(0));
        require(_isPrevCollator(cur, prev));
        collators[prev] = collators[cur];
        collators[cur] = address(0);
        fundOf[cur] = 0;
        count--;
    }

    function _increaseFund(address cur, uint256 fund, address oldPrev, address newPrev) internal {
        _updateFund(cur, fundOf[cur] + fund, oldPrev, newPrev);
    }

    function _reduceFund(address cur, uint256 fund, address oldPrev, address newPrev) internal {
        _updateCollator(cur, fundOf[cur] - fund, oldPrev, newPrev);
    }

    function _updateFund(address cur, uint256 newFund, address oldPrev, address newPrev) internal {
        require(collators[cur] != address(0));
        require(collators[oldPrev] != address(0));
        require(collators[newPrev] != address(0));
        if (oldPrev == newPrev) {
            require(_isPrevCollator(cur, oldPrev));
            require(_verifyIndex(newPrev, newFund, collators[cur]));
            fundOf[cur] = newFund;
        } else {
            _removeCollator(cur, oldPrev);
            _addCollator(cur, newFund, newPrev);
        }
    }

    // prev >= cur >= next
    function _verifyIndex(address prev, uint256 newValue, address next) internal view returns (bool) {
        return fundOf[prev] >= newValue && newValue >= fundOf[next];
    }

    function _isPrevCollator(address c, address prev) internal view returns (bool) {
        return collators[prev] == c;
    }
}
