// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./CollatorStakingHubStorage.sol";

abstract contract CollatorSet is Initializable, CollatorStakingHubStorage {
    address internal constant HEAD = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
    address internal constant TAIL = address(0x1);

    event AddCollator(address indexed cur, uint256 votes, address prev);
    event RemoveCollator(address indexed cur, address prev);
    event UpdateCollator(address indexed cur, uint256 votes, address oldPrev, address newPrev);

    function __CollatorSet_init() internal onlyInitializing {
        collators[HEAD] = TAIL;
        votesOf[HEAD] = type(uint256).max;
    }

    /// @dev Fetch top k collators in ordered collator set.
    /// @param `k` Count of top collators.
    /// @return The `k` top collators.
    /// *Note*  The result of top collators length is always be `k`.
    ///         If the length of collator set `len` is less than `k`,
    ///         the array result of first `len` is filled by nomal collators
    ///         and the rest of `len - k` collators is filled by address(0)
    function getTopCollators(uint256 k) public view returns (address[] memory) {
        address[] memory topCollators = new address[](k);
        uint256 len = count;
        if (len > k) len = k;
        address cur = collators[HEAD];
        for (uint256 i = 0; i < len; i++) {
            topCollators[i] = cur;
            cur = collators[cur];
        }
        return topCollators;
    }

    function _isValid(address c) internal pure returns (bool) {
        return c != address(0) && c != HEAD && c != TAIL;
    }

    function _isInactiveCollator(address c) public view returns (bool) {
        return _isValid(c) && collators[c] == address(0);
    }

    function _addCollator(address cur, uint256 votes, address prev) internal {
        require(_isValid(cur), "!valid");
        address next = collators[prev];
        // No duplicate collator allowed.
        require(collators[cur] == address(0), "!cur");
        // Next collator must in the list.
        require(next != address(0), "!prev");
        require(_verifyIndex(prev, votes, next, cur), "!votes");
        collators[cur] = next;
        collators[prev] = cur;
        votesOf[cur] = votes;
        count++;
        updateTimeStamp = block.timestamp;
        emit AddCollator(cur, votes, prev);
    }

    function _removeCollator(address cur, address prev) internal {
        require(_isValid(cur), "!valid");
        require(collators[cur] != address(0), "!cur");
        require(_isPrevCollator(cur, prev), "!prev");
        collators[prev] = collators[cur];
        collators[cur] = address(0);
        votesOf[cur] = 0;
        count--;
        updateTimeStamp = block.timestamp;
        emit RemoveCollator(cur, prev);
    }

    function _updateVotes(address cur, uint256 newVotes, address oldPrev, address newPrev) internal {
        require(_isValid(cur), "!valid");
        require(collators[cur] != address(0), "!cur");
        require(collators[oldPrev] != address(0), "!oldPrev1");
        require(collators[newPrev] != address(0), "!newPrev");
        if (oldPrev == newPrev) {
            require(_isPrevCollator(cur, oldPrev), "!oldPrev2");
            require(_verifyIndex(newPrev, newVotes, collators[cur], cur), "!votes");
            votesOf[cur] = newVotes;
            updateTimeStamp = block.timestamp;
        } else {
            _removeCollator(cur, oldPrev);
            _addCollator(cur, newVotes, newPrev);
        }
        emit UpdateCollator(cur, newVotes, oldPrev, newPrev);
    }

    // 1. votes(prev) >= votes(cur) >= votes(next)
    // 2. addr(prev) > addr(cur) > addr(next)
    function _verifyIndex(address prev, uint256 newValue, address next, address cur) internal view returns (bool) {
        return ((votesOf[prev] > newValue) || (votesOf[prev] == newValue && prev > cur))
            && ((newValue > votesOf[next]) || (newValue == votesOf[next] && cur > next));
    }

    function _isPrevCollator(address c, address prev) internal view returns (bool) {
        return collators[prev] == c;
    }
}
