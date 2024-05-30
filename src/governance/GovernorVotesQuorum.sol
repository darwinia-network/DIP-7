// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts@5.0.2/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts@5.0.2/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts@5.0.2/utils/math/SafeCast.sol";

abstract contract GovernorVotesQuorum is GovernorVotes {
    using Checkpoints for Checkpoints.Trace224;

    Checkpoints.Trace224 private _quorumHistory;

    event QuorumUpdated(uint256 oldQuorum, uint256 newQuorum);

    constructor(uint256 quorumValue) {
        _updateQuorum(quorumValue);
    }

    function quorum() public view virtual returns (uint256) {
        return _quorumHistory.latest();
    }

    function quorum(uint256 timepoint) public view virtual override returns (uint256) {
        uint256 length = _quorumHistory._checkpoints.length;

        // Optimistic search, check the latest checkpoint
        Checkpoints.Checkpoint224 memory latest = _quorumHistory._checkpoints[length - 1];
        if (latest._key <= timepoint) {
            return latest._value;
        }

        // Otherwise, do the binary search
        return _quorumHistory.upperLookupRecent(SafeCast.toUint32(timepoint));
    }

    function updateQuorum(uint256 newQuorum) external virtual onlyGovernance {
        _updateQuorum(newQuorum);
    }

    function _updateQuorum(uint256 newQuorum) internal virtual {
        uint256 oldQuorum = quorum();

        // Set new quorum for future proposals
        _quorumHistory.push(SafeCast.toUint32(clock()), SafeCast.toUint224(newQuorum));

        emit QuorumUpdated(oldQuorum, newQuorum);
    }
}
