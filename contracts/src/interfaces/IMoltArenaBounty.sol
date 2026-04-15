// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { MoltArenaTypes } from "../libraries/MoltArenaTypes.sol";
import { IMoltArenaVoteToken } from "./IMoltArenaVoteToken.sol";

interface IMoltArenaBounty {

    event SolutionSubmitted(
        uint256 indexed bountyId,
        uint256 indexed submissionId,
        address indexed submitter,
        string postURL,
        bytes32 contentHash
    );
    event SubmissionEligibilityUpdated(
        uint256 indexed bountyId,
        uint256 indexed submissionId,
        bool eligible,
        bytes32 contextHash
    );

    event VoteCommitted(uint256 indexed bountyId, address indexed voter, bytes32 commitHash, uint96 lockedCredits);

    event VoteRevealed(uint256 indexed bountyId, address indexed voter, bytes32 allocationHash, uint96 revealedCredits);

    event BountyFinalized(uint256 indexed bountyId, uint256[] winnerSubmissionIds, uint256 validRevealCount);
    event CreatorRefunded(uint256 indexed bountyId, address indexed creator, uint256 refundedAmount);

    event WinnerRewardClaimed(uint256 indexed bountyId, address indexed claimer, uint256 amount);
    event CuratorRewardClaimed(uint256 indexed bountyId, address indexed claimer, uint256 amount);

    error NotSettlementVerifier(uint256 bountyId, address caller, address expectedVerifier);
    error InvalidBountyInitialization();
    error InvalidSettlementScopeHash();
    error InvalidDeadlineOrder();
    error VoteWindowTooLong(uint256 requestedWindow, uint256 maxWindow);
    error RewardAmountZero();
    error WinnerCountZero();
    error MaxVoteCreditsPerVoterZero();
    error BountyAlreadyFinalized(uint256 bountyId);
    error BountyPhaseMismatch(
        uint256 bountyId,
        MoltArenaTypes.BountyStatus expected,
        MoltArenaTypes.BountyStatus actual
    );
    error SubmissionNotFound(uint256 bountyId, uint256 submissionId);
    error SubmissionAlreadyExists(uint256 bountyId, address submitter);
    error VoteAlreadyCommitted(uint256 bountyId, address voter);
    error VoteNotCommitted(uint256 bountyId, address voter);
    error VoteAlreadyRevealed(uint256 bountyId, address voter);
    error SelfVoteNotAllowed(uint256 bountyId, address voter, uint256 submissionId);
    error SubmissionNotEligible(uint256 bountyId, uint256 submissionId);
    error InvalidCommitHash();
    error InvalidVoteCredits(uint256 requested);
    error InvalidMoltbookReference();
    error ArrayLengthMismatch(uint256 leftLength, uint256 rightLength);
    error RevealCreditsMismatch(uint256 bountyId, address voter, uint256 expected, uint256 actual);
    error DuplicateSubmissionInReveal(uint256 submissionId);
    error InvalidRevealPayload();
    error VoteBudgetExceeded(uint256 bountyId, address voter, uint256 requested, uint256 available);
    error VotePerAddressCapExceeded(uint256 bountyId, address voter, uint256 requested, uint256 maxAllowed);
    error NoSubmissions(uint256 bountyId);
    error NoEligibleSubmissions(uint256 bountyId);
    error NoWinnerReward(uint256 bountyId, address claimer);
    error NoCuratorReward(uint256 bountyId, address claimer);
    error RewardAlreadyClaimed(uint256 bountyId, address claimer);

    function factory() external view returns (address);

    function bountyId() external view returns (uint256);

    function rewardToken() external view returns (IERC20);

    function voteToken() external view returns (IMoltArenaVoteToken);

    function winnerPoolBps() external pure returns (uint16);

    function curatorPoolBps() external pure returns (uint16);

    function maxVoteWindow() external pure returns (uint256);

    function initialize(
        uint256 bountyId_,
        IERC20 rewardToken_,
        IMoltArenaVoteToken voteToken_,
        address factory_,
        MoltArenaTypes.CreateBountyParams calldata params
    ) external;

    function currentStatus() external view returns (MoltArenaTypes.BountyStatus status);

    function submitSolution(
        string calldata postURL,
        bytes32 contentHash
    ) external returns (uint256 submissionId);

    function setSubmissionEligibility(
        uint256 submissionId,
        bool eligible,
        bytes32 contextHash
    ) external;

    function commitVote(
        bytes32 commitHash,
        uint96 creditsToLock
    ) external;

    function hashVoteAllocation(
        address voter,
        uint256[] calldata submissionIds,
        uint96[] calldata credits,
        bytes32 salt
    ) external view returns (bytes32);

    function revealVote(
        MoltArenaTypes.RevealVoteParams calldata params
    ) external;

    function finalizeBounty() external;

    function claimWinnerReward() external returns (uint256 amount);

    function claimCuratorReward() external returns (uint256 amount);

    function getBounty() external view returns (MoltArenaTypes.Bounty memory bounty);

    function getSubmission(
        uint256 submissionId
    ) external view returns (MoltArenaTypes.Submission memory submission);

    function getSubmissionIds() external view returns (uint256[] memory submissionIds);

    function getEligibleSubmissionIds() external view returns (uint256[] memory submissionIds);

    function getWinnerSubmissionIds() external view returns (uint256[] memory winnerSubmissionIds);

    function getVoteCommit(
        address voter
    ) external view returns (MoltArenaTypes.VoteCommit memory voteCommit);

    function hasSubmitted(
        address account
    ) external view returns (bool);

    function claimableRewards(
        address account
    ) external view returns (MoltArenaTypes.ClaimableRewards memory rewards);

}
