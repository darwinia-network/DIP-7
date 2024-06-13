// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../src/collator/CollatorSet.sol";

contract CollatorSetTest is Test, CollatorSet {
    address a = address(new One());
    address b = address(new One());
    address c = address(new One());

    function setUp() public initializer {
        __CollatorSet_init();
    }

    // function invariant_check() public view {
    //     assertTrue(collators[HEAD] != address(0));
    //     assertTrue(collators[TAIL] == address(0));
    // }

    function test_init() public view {
        assertEq(collators[HEAD], TAIL);
        assertEq(collators[TAIL], address(0));
        assertEq(votesOf[HEAD], type(uint256).max);
        assertEq(votesOf[TAIL], 0);
        checkCount(0);
    }

    function test_getTopCollators() public {
        address[] memory r = getTopCollators(2);
        assertEq(r.length, 2);
        assertEq(r[0], address(0));
        assertEq(r[1], address(0));
        perform_add();
        r = getTopCollators(2);
        assertEq(r.length, 2);
        assertEq(r[0], a);
        assertEq(r[1], b);
        r = getTopCollators(4);
        assertEq(r.length, 4);
        assertEq(r[0], a);
        assertEq(r[1], b);
        assertEq(r[2], c);
        assertEq(r[3], address(0));
    }

    function test__addCollator() public {
        perform_add();
        checkIndex(HEAD, a, b);
        checkIndex(a, b, c);
        checkIndex(b, c, TAIL);
        checkIn(a);
        checkIn(b);
        checkIn(c);
        checkCount(3);
    }

    function test__removeCollator() public {
        perform_add();
        perform_rm(a, HEAD);
        checkIndex(HEAD, b, c);
        checkIndex(b, c, TAIL);
        checkOut(a);
        checkIn(b);
        checkIn(c);
        checkCount(2);
        perform_rm(c, b);
        checkIndex(HEAD, b, TAIL);
        checkOut(a);
        checkIn(b);
        checkOut(c);
        checkCount(1);
        perform_rm(b, HEAD);
        checkOut(a);
        checkOut(b);
        checkOut(c);
        checkCount(0);
    }

    function test__increaseVotes() public {
        perform_add();
        perform_increase(c, 10 ether, b, HEAD);
        checkIndex(HEAD, c, a);
        checkIndex(c, a, b);
        checkIndex(a, b, TAIL);
        checkIn(a);
        checkIn(b);
        checkIn(c);
        checkCount(3);
    }

    function test__reduceVotes() public {
        perform_add();
        perform_reduce(a, 1.5 ether, HEAD, b);
        checkIndex(HEAD, b, a);
        checkIndex(b, a, c);
        checkIndex(a, c, TAIL);
        checkIn(a);
        checkIn(b);
        checkIn(c);
        checkCount(3);
    }

    function perform_add() public {
        _addCollator(a, 3 ether, HEAD);
        _addCollator(b, 2 ether, a);
        _addCollator(c, 1 ether, b);
    }

    function perform_rm(address cur, address prev) public {
        _removeCollator(cur, prev);
    }

    function perform_increase(address cur, uint256 votes, address oldPrev, address newPrev) public {
        _increaseVotes(cur, votes, oldPrev, newPrev);
    }

    function perform_reduce(address cur, uint256 votes, address oldPrev, address newPrev) public {
        _reduceVotes(cur, votes, oldPrev, newPrev);
    }

    function checkCount(uint256 cnt) public view {
        assertEq(cnt, count);
    }

    function checkIn(address cur) public view {
        assertTrue(collators[cur] != address(0) && cur != HEAD && cur != TAIL);
    }

    function checkOut(address cur) public view {
        assertTrue(collators[cur] == address(0) && cur != HEAD && cur != TAIL);
        assertEq(votesOf[cur], 0);
    }

    function checkIndex(address prev, address cur, address next) public view {
        assertTrue(collators[prev] == cur);
        assertTrue(collators[cur] == next);
        assertTrue(votesOf[prev] >= votesOf[cur]);
        assertTrue(votesOf[cur] >= votesOf[next]);
    }
}

contract One {}
