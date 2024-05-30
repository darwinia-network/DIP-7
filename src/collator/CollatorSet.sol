// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract CollatorSet {
    // collator count;
    uint256 public count;
    // ordered collators.
    mapping(address => address) public collators;
    // collator => score = staked_ring * (1 - commission)
    mapping(address => uint256) public scoreOf;

    address private constant HEAD = address(0x1);
    address private constant TAIL = address(0x2);

    event AddCollator(address indexed cur, uint256 score, address prev);
    event RemoveCollator(address indexed cur, address prev);
    event UpdateCollator(address indexed cur, uint256 score, address oldPrev, address newPrev);

    constructor() {
        collators[HEAD] = collators[TAIL];
        scoreOf[HEAD] = type(uint256).max;
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
            topCollators[i] = cur;
            cur = collators[cur];
        }
        return topCollators;
    }

    function _isValid(address c) internal pure returns (bool) {
        return c != address(0) && c != HEAD && c != TAIL;
    }

    function _addCollator(address cur, uint256 score, address prev) internal {
        require(_isValid(cur), "!valid");
        address next = collators[prev];
        // No duplicate collator allowed.
        require(collators[cur] == address(0), "!cur");
        // Next collaotr must in the list.
        require(next != address(0), "!prev");
        require(_verifyIndex(prev, score, next), "!score");
        collators[cur] = next;
        collators[prev] = cur;
        scoreOf[cur] = score;
        count++;
        emit AddCollator(cur, score, prev);
    }

    function _removeCollator(address cur, address prev) internal {
        require(_isValid(cur), "!valid");
        require(collators[cur] != address(0), "!cur");
        require(_isPrevCollator(cur, prev), "!prev");
        collators[prev] = collators[cur];
        collators[cur] = address(0);
        scoreOf[cur] = 0;
        count--;
        emit RemoveCollator(cur, prev);
    }

    function _increaseScore(address cur, uint256 score, address oldPrev, address newPrev) internal {
        _updateScore(cur, scoreOf[cur] + score, oldPrev, newPrev);
    }

    function _reduceScore(address cur, uint256 score, address oldPrev, address newPrev) internal {
        _updateScore(cur, scoreOf[cur] - score, oldPrev, newPrev);
    }

    function _updateScore(address cur, uint256 newScore, address oldPrev, address newPrev) internal {
        require(_isValid(cur), "!valid");
        require(collators[cur] != address(0), "!cur");
        require(collators[oldPrev] != address(0), "!oldPrev");
        require(collators[newPrev] != address(0), "!newPrev");
        if (oldPrev == newPrev) {
            require(_isPrevCollator(cur, oldPrev), "!oldPrev");
            require(_verifyIndex(newPrev, newScore, collators[cur]), "!score");
            scoreOf[cur] = newScore;
        } else {
            _removeCollator(cur, oldPrev);
            _addCollator(cur, newScore, newPrev);
        }
        emit UpdateCollator(cur, newScore, oldPrev, newPrev);
    }

    // prev >= cur >= next
    function _verifyIndex(address prev, uint256 newValue, address next) internal view returns (bool) {
        return scoreOf[prev] >= newValue && newValue >= scoreOf[next];
    }

    function _isPrevCollator(address c, address prev) internal view returns (bool) {
        return collators[prev] == c;
    }
}
