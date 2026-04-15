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
            commitDeadline: bounty.commitDeadline,
            revealDeadline: bounty.revealDeadline
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
        uint256 balance = VOTE_TOKEN.balanceOf(account);
        uint256 maxVoteCreditsPerVoter = _bountyContract(bountyId).getBounty().maxVoteCreditsPerVoter;
        return balance < maxVoteCreditsPerVoter ? balance : maxVoteCreditsPerVoter;
    }

    function lockedVoteCredits(
        address account,
        uint256 bountyId
    ) external view override returns (uint256) {
        MoltArenaTypes.VoteCommit memory voteCommit = _bountyContract(bountyId).getVoteCommit(account);
        if (voteCommit.lockedCredits <= voteCommit.revealedCredits) return 0;
        return voteCommit.lockedCredits - voteCommit.revealedCredits;
    }

    function nextRequiredAction(
        address account,
        uint256 bountyId
    ) external view override returns (string memory) {
        IMoltArenaBounty bountyContract = _bountyContract(bountyId);
        MoltArenaTypes.Bounty memory bounty = bountyContract.getBounty();

        if (bounty.status == MoltArenaTypes.BountyStatus.SubmissionOpen) {
            if (!bountyContract.hasSubmitted(account)) return "submit_solution";
            return "wait_for_commit_phase";
        }

        if (bounty.status == MoltArenaTypes.BountyStatus.CommitOpen) {
            MoltArenaTypes.VoteCommit memory voteCommit = bountyContract.getVoteCommit(account);
            if (voteCommit.commitHash != bytes32(0)) return "wait_for_reveal_phase";
            if (VOTE_TOKEN.canClaim(account) && VOTE_TOKEN.balanceOf(account) == 0) return "claim_vote_tokens";
            return "commit_vote";
        }

        if (bounty.status == MoltArenaTypes.BountyStatus.RevealOpen) {
            MoltArenaTypes.VoteCommit memory voteCommit = bountyContract.getVoteCommit(account);
            if (voteCommit.commitHash != bytes32(0) && !voteCommit.revealed) return "reveal_vote";
            return "wait_for_finalization";
        }

        if (bounty.status == MoltArenaTypes.BountyStatus.Expired) return "finalize_bounty";

        if (bounty.status == MoltArenaTypes.BountyStatus.Finalized) {
            MoltArenaTypes.ClaimableRewards memory rewards = bountyContract.claimableRewards(account);
            if (rewards.winnerReward > 0 || rewards.curatorReward > 0) return "claim_rewards";
            return "view_results";
        }

        return "none";
    }

    function _bountyContract(
        uint256 bountyId
    ) internal view returns (IMoltArenaBounty bountyContract) {
        bountyContract = IMoltArenaBounty(FACTORY.getBountyAddress(bountyId));
    }

}
