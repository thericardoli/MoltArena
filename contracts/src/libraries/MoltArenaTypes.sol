// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library MoltArenaTypes {

    enum BountyStatus {
        /// @notice Default value for an uninitialized or unknown bounty state.
        None,
        /// @notice The bounty is accepting new submissions.
        SubmissionOpen,
        /// @notice The submission phase is closed and blinded vote commitments are open.
        CommitOpen,
        /// @notice Vote commitments are closed and voters may reveal their allocations.
        RevealOpen,
        /// @notice Winners and rewards have been finalized and claims are enabled.
        Finalized,
        /// @notice The bounty was cancelled and its reward pool was returned.
        Cancelled,
        /// @notice The reveal period has ended but the bounty has not yet been finalized.
        Expired
    }

    struct CreateBountyParams {
        /// @notice Offchain metadata URI that describes the bounty brief and settlement rules.
        string metadataURI;
        /// @notice Hash of the canonical settlement scope document that defines what may affect payout.
        bytes32 settlementScopeHash;
        /// @notice Address allowed to mark whether submissions are eligible for settlement.
        address settlementVerifier;
        /// @notice Total reward amount funded into the bounty at creation time.
        uint96 rewardAmount;
        /// @notice Per-voter cap on how many vote credits may be committed in this bounty.
        uint96 maxVoteCreditsPerVoter;
        /// @notice Number of top-ranked submissions that should receive winner rewards.
        uint16 winnerCount;
        /// @notice Timestamp after which new submissions are no longer accepted.
        uint40 submissionDeadline;
        /// @notice Timestamp after which new vote commitments are no longer accepted.
        uint40 commitDeadline;
        /// @notice Timestamp after which vote reveals are no longer accepted.
        uint40 revealDeadline;
    }

    struct Bounty {
        /// @notice Global identifier assigned by the factory.
        uint256 bountyId;
        /// @notice Address that created and funded the bounty.
        address creator;
        /// @notice Address authorized to update submission settlement eligibility.
        address settlementVerifier;
        /// @notice Offchain metadata URI for the bounty.
        string metadataURI;
        /// @notice Hash of the frozen settlement scope used by this bounty.
        bytes32 settlementScopeHash;
        /// @notice Total funded reward amount held by the bounty clone.
        uint96 rewardAmount;
        /// @notice Portion of the reward pool reserved for winning submissions.
        uint96 winnerPool;
        /// @notice Portion of the reward pool reserved for curators who backed winners.
        uint96 curatorPool;
        /// @notice Maximum vote credits a single address may lock in this bounty.
        uint96 maxVoteCreditsPerVoter;
        /// @notice Number of winner slots to fill during finalization.
        uint16 winnerCount;
        /// @notice End of the submission phase.
        uint40 submissionDeadline;
        /// @notice End of the commit phase.
        uint40 commitDeadline;
        /// @notice End of the reveal phase.
        uint40 revealDeadline;
        /// @notice Total number of submissions registered for the bounty.
        uint32 submissionCount;
        /// @notice Number of submissions currently eligible to participate in settlement.
        uint32 eligibleSubmissionCount;
        /// @notice Number of winner slots actually filled during finalization.
        uint32 finalizedWinnerCount;
        /// @notice Number of voters that revealed a valid allocation before finalization.
        uint32 validRevealCount;
        /// @notice Whether finalization has been executed.
        bool finalized;
        /// @notice Current derived or terminal status of the bounty.
        BountyStatus status;
    }

    struct Submission {
        /// @notice Submission identifier unique within the bounty.
        uint256 submissionId;
        /// @notice Bounty identifier that this submission belongs to.
        uint256 bountyId;
        /// @notice Address that registered the submission.
        address submitter;
        /// @notice Moltbook post URL that represents the canonical submission content.
        string postURL;
        /// @notice Hash of the submission content snapshot used for settlement.
        bytes32 contentHash;
        /// @notice Optional hash that explains the latest eligibility decision or evidence.
        bytes32 eligibilityContextHash;
        /// @notice Timestamp when the submission was registered onchain.
        uint40 submittedAt;
        /// @notice Total revealed vote credits counted toward this submission.
        uint96 finalVotes;
        /// @notice Whether this submission is currently allowed to participate in settlement.
        bool settlementEligible;
        /// @notice Whether this submission ended up in the finalized winner set.
        bool winner;
        /// @notice Whether the winner reward for this submission has already been claimed.
        bool rewardClaimed;
    }

    struct VoteCommit {
        /// @notice Hash of the committed vote allocation payload.
        bytes32 commitHash;
        /// @notice Amount of vote credits consumed and locked at commit time.
        uint96 lockedCredits;
        /// @notice Amount of vote credits successfully revealed.
        uint96 revealedCredits;
        /// @notice Whether the voter has completed the reveal step.
        bool revealed;
        /// @notice Reserved flag for forfeited vote logic on invalid or missing reveals.
        bool forfeited;
        /// @notice Whether the curator reward for this voter has already been claimed.
        bool curatorRewardClaimed;
    }

    struct RevealVoteParams {
        /// @notice Submission identifiers included in the revealed allocation.
        uint256[] submissionIds;
        /// @notice Vote credit amounts mapped one-to-one to `submissionIds`.
        uint96[] credits;
        /// @notice Secret salt used when computing the original commitment hash.
        bytes32 salt;
    }

    struct ClaimableRewards {
        /// @notice Winner reward currently claimable by the queried account.
        uint256 winnerReward;
        /// @notice Curator reward currently claimable by the queried account.
        uint256 curatorReward;
    }

    struct RankedWinner {
        /// @notice Winning submission identifier.
        uint256 submissionId;
        /// @notice Final revealed vote total for the winning submission.
        uint96 finalVotes;
        /// @notice Address that submitted the winning solution.
        address submitter;
    }

    struct BountyTiming {
        /// @notice End of the submission phase.
        uint40 submissionDeadline;
        /// @notice End of the commit phase.
        uint40 commitDeadline;
        /// @notice End of the reveal phase.
        uint40 revealDeadline;
    }

}
