// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IMoltArenaBounty } from "./interfaces/IMoltArenaBounty.sol";
import { IMoltArenaFactory } from "./interfaces/IMoltArenaFactory.sol";
import { IMoltArenaLens } from "./interfaces/IMoltArenaLens.sol";
import { IMoltArenaVoteToken } from "./interfaces/IMoltArenaVoteToken.sol";
import { MoltArenaTypes } from "./libraries/MoltArenaTypes.sol";

contract MoltArenaLens is IMoltArenaLens {

    IMoltArenaFactory public immutable FACTORY;
    IMoltArenaVoteToken public immutable VOTE_TOKEN;

    constructor(
        IMoltArenaFactory factory_
    ) {
        FACTORY = factory_;
        VOTE_TOKEN = factory_.voteToken();
    }

    function getBountyAddress(
        uint256 bountyId
    ) public view override returns (address bounty) {
        bounty = FACTORY.getBountyAddress(bountyId);
    }

    function currentStatus(
        uint256 bountyId
    ) external view override returns (MoltArenaTypes.BountyStatus) {
        return _bountyContract(bountyId).currentStatus();
    }

    function getBounty(
        uint256 bountyId
    ) public view override returns (MoltArenaTypes.Bounty memory bounty) {
        bounty = _bountyContract(bountyId).getBounty();
    }

    function getBounties(
        uint256 startId,
        uint256 limit
    ) external view override returns (MoltArenaTypes.Bounty[] memory bounties) {
        address[] memory bountyAddresses = FACTORY.getBountyAddresses(startId, limit);
        bounties = new MoltArenaTypes.Bounty[](bountyAddresses.length);

        for (uint256 i; i < bountyAddresses.length; ++i) {
            bounties[i] = IMoltArenaBounty(bountyAddresses[i]).getBounty();
        }
    }

    function getBountyTiming(
        uint256 bountyId
    ) external view override returns (MoltArenaTypes.BountyTiming memory timing) {
        MoltArenaTypes.Bounty memory bounty = _bountyContract(bountyId).getBounty();
        timing = MoltArenaTypes.BountyTiming({
            submissionDeadline: bounty.submissionDeadline,
            voteDeadline: bounty.voteDeadline
        });
    }

    function getSubmissionIds(
        uint256 bountyId
    ) external view override returns (uint256[] memory submissionIds) {
        return _bountyContract(bountyId).getSubmissionIds();
    }

    function getEligibleSubmissionIds(
        uint256 bountyId
    ) external view override returns (uint256[] memory submissionIds) {
        return _bountyContract(bountyId).getEligibleSubmissionIds();
    }

    function getWinnerSubmissionIds(
        uint256 bountyId
    ) external view override returns (uint256[] memory winnerIds) {
        return _bountyContract(bountyId).getWinnerSubmissionIds();
    }

    function getRankedWinners(
        uint256 bountyId
    ) external view override returns (MoltArenaTypes.RankedWinner[] memory winners) {
        IMoltArenaBounty bountyContract = _bountyContract(bountyId);
        uint256[] memory winnerIds = bountyContract.getWinnerSubmissionIds();
        winners = new MoltArenaTypes.RankedWinner[](winnerIds.length);

        for (uint256 i; i < winnerIds.length; ++i) {
            MoltArenaTypes.Submission memory submission = bountyContract.getSubmission(winnerIds[i]);
            winners[i] = MoltArenaTypes.RankedWinner({
                submissionId: submission.submissionId,
                finalVotes: submission.finalVotes,
                submitter: submission.submitter
            });
        }
    }

    function availableVoteCredits(
        address account,
        uint256 bountyId
    ) external view override returns (uint256) {
        if (_bountyContract(bountyId).getVoteRecord(account).usedCredits > 0) return 0;
        uint256 balance = VOTE_TOKEN.balanceOf(account);
        uint256 maxVoteCreditsPerVoter = _bountyContract(bountyId).getBounty().maxVoteCreditsPerVoter;
        return balance < maxVoteCreditsPerVoter ? balance : maxVoteCreditsPerVoter;
    }

    function usedVoteCredits(
        address account,
        uint256 bountyId
    ) external view override returns (uint256) {
        return _bountyContract(bountyId).getVoteRecord(account).usedCredits;
    }

    function _bountyContract(
        uint256 bountyId
    ) internal view returns (IMoltArenaBounty bountyContract) {
        bountyContract = IMoltArenaBounty(FACTORY.getBountyAddress(bountyId));
    }

}
