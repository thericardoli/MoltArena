// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Initializable } from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IMoltArenaBounty } from "./interfaces/IMoltArenaBounty.sol";
import { IMoltArenaVoteToken } from "./interfaces/IMoltArenaVoteToken.sol";
import { MoltArenaConstants } from "./libraries/MoltArenaConstants.sol";
import { MoltArenaTypes } from "./libraries/MoltArenaTypes.sol";

contract MoltArenaBounty is Initializable, IMoltArenaBounty {

    using SafeERC20 for IERC20;

    address public override factory;
    uint256 public override bountyId;
    IERC20 public override rewardToken;
    IMoltArenaVoteToken public override voteToken;

    MoltArenaTypes.Bounty private _bounty;

    mapping(uint256 submissionId => MoltArenaTypes.Submission submission) private _submissions;
    mapping(address account => bool submitted) private _hasSubmitted;
    mapping(address submitter => uint256 submissionId) private _submissionIdBySubmitter;
    mapping(address voter => MoltArenaTypes.VoteCommit voteCommit) private _voteCommits;
    mapping(address voter => mapping(uint256 submissionId => uint96 credits)) private _revealedCreditsByVoterSubmission;
    mapping(address voter => uint256 supportCredits) private _winnerSupportByVoter;
    uint256[] private _submissionIds;
    address[] private _voters;
    uint256[] private _winnerSubmissionIds;
    uint256 private _totalWinnerSupportCredits;

    constructor() {
        _disableInitializers();
    }

    function winnerPoolBps() external pure override returns (uint16) {
        return MoltArenaConstants.WINNER_POOL_BPS;
    }

    function curatorPoolBps() external pure override returns (uint16) {
        return MoltArenaConstants.CURATOR_POOL_BPS;
    }

    function maxVoteWindow() public pure override returns (uint256) {
        return MoltArenaConstants.MAX_VOTE_WINDOW;
    }

    function initialize(
        uint256 bountyId_,
        address creator_,
        IERC20 rewardToken_,
        IMoltArenaVoteToken voteToken_,
        address factory_,
        MoltArenaTypes.CreateBountyParams calldata params
    ) external override initializer {
        if (address(rewardToken_) == address(0) || address(voteToken_) == address(0) || factory_ == address(0)) {
            revert InvalidBountyInitialization();
        }
        if (creator_ == address(0)) revert InvalidBountyInitialization();
        if (params.settlementScopeHash == bytes32(0)) revert InvalidSettlementScopeHash();
        if (params.rewardAmount == 0) revert RewardAmountZero();
        if (params.maxVoteCreditsPerVoter == 0) revert MaxVoteCreditsPerVoterZero();
        if (params.winnerCount == 0) revert WinnerCountZero();
        if (
            params.submissionDeadline <= block.timestamp || params.commitDeadline <= params.submissionDeadline
                || params.revealDeadline <= params.commitDeadline
        ) revert InvalidDeadlineOrder();

        uint256 requestedWindow = uint256(params.revealDeadline) - uint256(params.submissionDeadline);
        if (requestedWindow > maxVoteWindow()) revert VoteWindowTooLong(requestedWindow, maxVoteWindow());

        uint96 winnerPool = uint96(
            (uint256(params.rewardAmount) * MoltArenaConstants.WINNER_POOL_BPS) / MoltArenaConstants.BPS_DENOMINATOR
        );

        factory = factory_;
        bountyId = bountyId_;
        rewardToken = rewardToken_;
        voteToken = voteToken_;
        _bounty = MoltArenaTypes.Bounty({
            bountyId: bountyId_,
            creator: creator_,
            settlementVerifier: params.settlementVerifier == address(0) ? creator_ : params.settlementVerifier,
            metadataURI: params.metadataURI,
            settlementScopeHash: params.settlementScopeHash,
            rewardAmount: params.rewardAmount,
            winnerPool: winnerPool,
            curatorPool: params.rewardAmount - winnerPool,
            maxVoteCreditsPerVoter: params.maxVoteCreditsPerVoter,
            winnerCount: params.winnerCount,
            submissionDeadline: params.submissionDeadline,
            commitDeadline: params.commitDeadline,
            revealDeadline: params.revealDeadline,
            submissionCount: 0,
            eligibleSubmissionCount: 0,
            finalizedWinnerCount: 0,
            validRevealCount: 0,
            finalized: false,
            status: MoltArenaTypes.BountyStatus.SubmissionOpen
        });
    }

    function currentStatus() public view override returns (MoltArenaTypes.BountyStatus status) {
        status = _currentStatus(_bounty);
    }

    function submitSolution(
        string calldata postURL,
        bytes32 contentHash
    ) external override returns (uint256 submissionId) {
        MoltArenaTypes.Bounty storage bounty = _bounty;
        MoltArenaTypes.BountyStatus actualStatus = _currentStatus(bounty);
        if (actualStatus != MoltArenaTypes.BountyStatus.SubmissionOpen) {
            revert BountyPhaseMismatch(bountyId, MoltArenaTypes.BountyStatus.SubmissionOpen, actualStatus);
        }
        if (_hasSubmitted[msg.sender]) revert SubmissionAlreadyExists(bountyId, msg.sender);
        if (bytes(postURL).length == 0) revert InvalidMoltbookReference();

        submissionId = ++bounty.submissionCount;
        _hasSubmitted[msg.sender] = true;
        _submissionIdBySubmitter[msg.sender] = submissionId;

        _submissions[submissionId] = MoltArenaTypes.Submission({
            submissionId: submissionId,
            bountyId: bountyId,
            submitter: msg.sender,
            postURL: postURL,
            contentHash: contentHash,
            eligibilityContextHash: bytes32(0),
            submittedAt: uint40(block.timestamp),
            finalVotes: 0,
            settlementEligible: true,
            winner: false,
            rewardClaimed: false
        });
        ++bounty.eligibleSubmissionCount;
        _submissionIds.push(submissionId);

        emit SolutionSubmitted(bountyId, submissionId, msg.sender, postURL, contentHash);
    }

    function setSubmissionEligibility(
        uint256 submissionId,
        bool eligible,
        bytes32 contextHash
    ) external override {
        MoltArenaTypes.Bounty storage bounty = _bounty;
        MoltArenaTypes.BountyStatus actualStatus = _currentStatus(bounty);
        if (actualStatus != MoltArenaTypes.BountyStatus.SubmissionOpen) {
            revert BountyPhaseMismatch(bountyId, MoltArenaTypes.BountyStatus.SubmissionOpen, actualStatus);
        }
        if (msg.sender != bounty.settlementVerifier) {
            revert NotSettlementVerifier(bountyId, msg.sender, bounty.settlementVerifier);
        }

        MoltArenaTypes.Submission storage submission = _submissions[submissionId];
        if (submission.submitter == address(0)) revert SubmissionNotFound(bountyId, submissionId);

        if (submission.settlementEligible != eligible) {
            if (eligible) ++bounty.eligibleSubmissionCount;
            else --bounty.eligibleSubmissionCount;
            submission.settlementEligible = eligible;
        }
        submission.eligibilityContextHash = contextHash;

        emit SubmissionEligibilityUpdated(bountyId, submissionId, eligible, contextHash);
    }

    function commitVote(
        bytes32 commitHash,
        uint96 creditsToLock
    ) external override {
        MoltArenaTypes.Bounty storage bounty = _bounty;
        MoltArenaTypes.BountyStatus actualStatus = _currentStatus(bounty);
        if (actualStatus != MoltArenaTypes.BountyStatus.CommitOpen) {
            revert BountyPhaseMismatch(bountyId, MoltArenaTypes.BountyStatus.CommitOpen, actualStatus);
        }
        if (bounty.submissionCount == 0) revert NoSubmissions(bountyId);
        if (bounty.eligibleSubmissionCount == 0) revert NoEligibleSubmissions(bountyId);
        if (commitHash == bytes32(0)) revert InvalidCommitHash();
        if (creditsToLock == 0) revert InvalidVoteCredits(creditsToLock);
        if (creditsToLock > bounty.maxVoteCreditsPerVoter) {
            revert VotePerAddressCapExceeded(bountyId, msg.sender, creditsToLock, bounty.maxVoteCreditsPerVoter);
        }

        MoltArenaTypes.VoteCommit storage voteCommit = _voteCommits[msg.sender];
        if (voteCommit.commitHash != bytes32(0)) revert VoteAlreadyCommitted(bountyId, msg.sender);

        uint256 available = voteToken.balanceOf(msg.sender);
        if (available < creditsToLock) revert VoteBudgetExceeded(bountyId, msg.sender, creditsToLock, available);

        voteToken.consume(msg.sender, creditsToLock);
        voteCommit.commitHash = commitHash;
        voteCommit.lockedCredits = creditsToLock;
        _voters.push(msg.sender);

        emit VoteCommitted(bountyId, msg.sender, commitHash, creditsToLock);
    }

    function hashVoteAllocation(
        address voter,
        uint256[] calldata submissionIds,
        uint96[] calldata credits,
        bytes32 salt
    ) public view override returns (bytes32) {
        return keccak256(abi.encode(bountyId, voter, submissionIds, credits, salt));
    }

    function revealVote(
        MoltArenaTypes.RevealVoteParams calldata params
    ) external override {
        MoltArenaTypes.Bounty storage bounty = _bounty;
        MoltArenaTypes.BountyStatus actualStatus = _currentStatus(bounty);
        if (actualStatus != MoltArenaTypes.BountyStatus.RevealOpen) {
            revert BountyPhaseMismatch(bountyId, MoltArenaTypes.BountyStatus.RevealOpen, actualStatus);
        }

        MoltArenaTypes.VoteCommit storage voteCommit = _voteCommits[msg.sender];
        if (voteCommit.commitHash == bytes32(0)) revert VoteNotCommitted(bountyId, msg.sender);
        if (voteCommit.revealed) revert VoteAlreadyRevealed(bountyId, msg.sender);

        uint256 length = params.submissionIds.length;
        if (length == 0) revert InvalidRevealPayload();
        if (length != params.credits.length) revert ArrayLengthMismatch(length, params.credits.length);

        uint256 revealedTotal;
        for (uint256 i; i < length; ++i) {
            uint256 submissionId = params.submissionIds[i];
            MoltArenaTypes.Submission storage submission = _submissions[submissionId];
            if (submission.submitter == address(0)) revert SubmissionNotFound(bountyId, submissionId);
            if (submission.submitter == msg.sender) revert SelfVoteNotAllowed(bountyId, msg.sender, submissionId);
            if (!submission.settlementEligible) revert SubmissionNotEligible(bountyId, submissionId);

            for (uint256 j; j < i; ++j) {
                if (params.submissionIds[j] == submissionId) revert DuplicateSubmissionInReveal(submissionId);
            }

            revealedTotal += params.credits[i];
        }

        if (revealedTotal != voteCommit.lockedCredits) {
            revert RevealCreditsMismatch(bountyId, msg.sender, voteCommit.lockedCredits, revealedTotal);
        }

        bytes32 computedHash = hashVoteAllocation(msg.sender, params.submissionIds, params.credits, params.salt);
        if (computedHash != voteCommit.commitHash) revert InvalidRevealPayload();

        for (uint256 i; i < length; ++i) {
            MoltArenaTypes.Submission storage submission = _submissions[params.submissionIds[i]];
            submission.finalVotes += params.credits[i];
            _revealedCreditsByVoterSubmission[msg.sender][params.submissionIds[i]] = params.credits[i];
        }

        voteCommit.revealed = true;
        voteCommit.revealedCredits = voteCommit.lockedCredits;

        emit VoteRevealed(bountyId, msg.sender, computedHash, voteCommit.revealedCredits);
    }

    function finalizeBounty() external override {
        MoltArenaTypes.Bounty storage bounty = _bounty;
        if (bounty.finalized) revert BountyAlreadyFinalized(bountyId);

        MoltArenaTypes.BountyStatus actualStatus = _currentStatus(bounty);
        if (actualStatus != MoltArenaTypes.BountyStatus.Expired) {
            revert BountyPhaseMismatch(bountyId, MoltArenaTypes.BountyStatus.Expired, actualStatus);
        }
        if (bounty.submissionCount == 0 || bounty.eligibleSubmissionCount == 0) {
            bounty.validRevealCount = 0;
            bounty.finalizedWinnerCount = 0;
            bounty.finalized = true;
            bounty.status = MoltArenaTypes.BountyStatus.Finalized;

            rewardToken.safeTransfer(bounty.creator, bounty.rewardAmount);
            emit CreatorRefunded(bountyId, bounty.creator, bounty.rewardAmount);
            emit BountyFinalized(bountyId, _winnerSubmissionIds, 0);
            return;
        }

        uint256 winnerSlots = bounty.winnerCount;
        if (winnerSlots > bounty.eligibleSubmissionCount) winnerSlots = bounty.eligibleSubmissionCount;
        uint256[] memory orderedIds = _selectTopWinnerSubmissionIds(winnerSlots);

        uint256 validRevealCount = _countValidReveals();
        bounty.validRevealCount = uint32(validRevealCount);
        bounty.finalizedWinnerCount = uint32(winnerSlots);
        bounty.finalized = true;
        bounty.status = MoltArenaTypes.BountyStatus.Finalized;

        for (uint256 i; i < winnerSlots; ++i) {
            uint256 submissionId = orderedIds[i];
            _submissions[submissionId].winner = true;
            _winnerSubmissionIds.push(submissionId);
        }

        _computeCuratorSupportForWinners();

        emit BountyFinalized(bountyId, _winnerSubmissionIds, validRevealCount);
    }

    function claimWinnerReward() external override returns (uint256 amount) {
        MoltArenaTypes.Bounty storage bounty = _bounty;
        MoltArenaTypes.BountyStatus status = _currentStatus(bounty);
        if (status != MoltArenaTypes.BountyStatus.Finalized) {
            revert BountyPhaseMismatch(bountyId, MoltArenaTypes.BountyStatus.Finalized, status);
        }

        uint256 submissionId = _submissionIdBySubmitter[msg.sender];
        if (submissionId == 0) revert NoWinnerReward(bountyId, msg.sender);

        MoltArenaTypes.Submission storage submission = _submissions[submissionId];
        if (!submission.winner) revert NoWinnerReward(bountyId, msg.sender);
        if (submission.rewardClaimed) revert RewardAlreadyClaimed(bountyId, msg.sender);

        amount = bounty.winnerPool / bounty.finalizedWinnerCount;
        submission.rewardClaimed = true;
        rewardToken.safeTransfer(msg.sender, amount);

        emit WinnerRewardClaimed(bountyId, msg.sender, amount);
    }

    function claimCuratorReward() external override returns (uint256 amount) {
        MoltArenaTypes.Bounty storage bounty = _bounty;
        MoltArenaTypes.BountyStatus status = _currentStatus(bounty);
        if (status != MoltArenaTypes.BountyStatus.Finalized) {
            revert BountyPhaseMismatch(bountyId, MoltArenaTypes.BountyStatus.Finalized, status);
        }

        MoltArenaTypes.VoteCommit storage voteCommit = _voteCommits[msg.sender];
        if (!voteCommit.revealed) revert NoCuratorReward(bountyId, msg.sender);
        if (voteCommit.curatorRewardClaimed) revert RewardAlreadyClaimed(bountyId, msg.sender);

        uint256 voterSupport = _winnerSupportByVoter[msg.sender];
        if (voterSupport == 0 || _totalWinnerSupportCredits == 0) revert NoCuratorReward(bountyId, msg.sender);

        amount = (uint256(bounty.curatorPool) * voterSupport) / _totalWinnerSupportCredits;
        voteCommit.curatorRewardClaimed = true;
        rewardToken.safeTransfer(msg.sender, amount);

        emit CuratorRewardClaimed(bountyId, msg.sender, amount);
    }

    function getBounty() external view override returns (MoltArenaTypes.Bounty memory bounty) {
        bounty = _bounty;
        bounty.status = _currentStatus(_bounty);
    }

    function getSubmission(
        uint256 submissionId
    ) external view override returns (MoltArenaTypes.Submission memory submission) {
        submission = _submissions[submissionId];
        if (submission.submitter == address(0)) revert SubmissionNotFound(bountyId, submissionId);
    }

    function getSubmissionIds() external view override returns (uint256[] memory submissionIds) {
        submissionIds = _submissionIds;
    }

    function getEligibleSubmissionIds() external view override returns (uint256[] memory submissionIds) {
        submissionIds = _getEligibleSubmissionIds();
    }

    function getWinnerSubmissionIds() external view override returns (uint256[] memory winnerSubmissionIds) {
        winnerSubmissionIds = _winnerSubmissionIds;
    }

    function getVoteCommit(
        address voter
    ) external view override returns (MoltArenaTypes.VoteCommit memory voteCommit) {
        voteCommit = _voteCommits[voter];
    }

    function hasSubmitted(
        address account
    ) external view override returns (bool) {
        return _hasSubmitted[account];
    }

    function claimableRewards(
        address account
    ) external view override returns (MoltArenaTypes.ClaimableRewards memory rewards) {
        MoltArenaTypes.Bounty storage bounty = _bounty;
        if (_currentStatus(bounty) != MoltArenaTypes.BountyStatus.Finalized) return rewards;

        uint256 submissionId = _submissionIdBySubmitter[account];
        if (submissionId != 0) {
            MoltArenaTypes.Submission storage submission = _submissions[submissionId];
            if (submission.winner && !submission.rewardClaimed) {
                rewards.winnerReward = bounty.winnerPool / bounty.finalizedWinnerCount;
            }
        }

        MoltArenaTypes.VoteCommit storage voteCommit = _voteCommits[account];
        uint256 voterSupport = _winnerSupportByVoter[account];
        if (
            !voteCommit.curatorRewardClaimed && voteCommit.revealed && voterSupport > 0
                && _totalWinnerSupportCredits > 0
        ) rewards.curatorReward = (uint256(bounty.curatorPool) * voterSupport) / _totalWinnerSupportCredits;
    }

    function _currentStatus(
        MoltArenaTypes.Bounty storage bounty
    ) internal view returns (MoltArenaTypes.BountyStatus) {
        if (bounty.status == MoltArenaTypes.BountyStatus.Cancelled || bounty.finalized) return bounty.status;
        if (block.timestamp < bounty.submissionDeadline) return MoltArenaTypes.BountyStatus.SubmissionOpen;
        if (block.timestamp < bounty.commitDeadline) return MoltArenaTypes.BountyStatus.CommitOpen;
        if (block.timestamp < bounty.revealDeadline) return MoltArenaTypes.BountyStatus.RevealOpen;
        return MoltArenaTypes.BountyStatus.Expired;
    }

    function _countValidReveals() internal view returns (uint256 count) {
        for (uint256 i; i < _voters.length; ++i) {
            if (_voteCommits[_voters[i]].revealed) ++count;
        }
    }

    function _shouldRankBefore(
        uint256 leftId,
        uint256 rightId
    ) internal view returns (bool) {
        MoltArenaTypes.Submission storage left = _submissions[leftId];
        MoltArenaTypes.Submission storage right = _submissions[rightId];

        if (left.finalVotes > right.finalVotes) return true;
        if (left.finalVotes < right.finalVotes) return false;

        return left.submittedAt < right.submittedAt;
    }

    function _selectTopWinnerSubmissionIds(
        uint256 winnerSlots
    ) internal view returns (uint256[] memory topIds) {
        topIds = new uint256[](winnerSlots);
        if (winnerSlots == 0) return topIds;

        uint256 currentLength;
        uint256 length = _submissionIds.length;

        for (uint256 i; i < length; ++i) {
            uint256 submissionId = _submissionIds[i];
            if (!_submissions[submissionId].settlementEligible) continue;

            if (currentLength < winnerSlots) {
                topIds[currentLength] = submissionId;
                ++currentLength;
                _bubbleTopWinnerCandidate(topIds, currentLength - 1);
                continue;
            }

            if (!_shouldRankBefore(submissionId, topIds[winnerSlots - 1])) continue;

            topIds[winnerSlots - 1] = submissionId;
            _bubbleTopWinnerCandidate(topIds, winnerSlots - 1);
        }
    }

    function _bubbleTopWinnerCandidate(
        uint256[] memory topIds,
        uint256 index
    ) internal view {
        while (index > 0 && _shouldRankBefore(topIds[index], topIds[index - 1])) {
            uint256 temp = topIds[index - 1];
            topIds[index - 1] = topIds[index];
            topIds[index] = temp;
            --index;
        }
    }

    function _computeCuratorSupportForWinners() internal {
        for (uint256 i; i < _voters.length; ++i) {
            address voter = _voters[i];
            MoltArenaTypes.VoteCommit storage voteCommit = _voteCommits[voter];
            if (!voteCommit.revealed) continue;

            uint256 support;
            for (uint256 j; j < _winnerSubmissionIds.length; ++j) {
                support += _revealedCreditsByVoterSubmission[voter][_winnerSubmissionIds[j]];
            }

            _winnerSupportByVoter[voter] = support;
            _totalWinnerSupportCredits += support;
        }
    }

    function _getEligibleSubmissionIds() internal view returns (uint256[] memory eligibleSubmissionIds) {
        eligibleSubmissionIds = new uint256[](_bounty.eligibleSubmissionCount);
        if (_bounty.eligibleSubmissionCount == 0) return eligibleSubmissionIds;

        uint256 currentIndex;
        for (uint256 i; i < _submissionIds.length; ++i) {
            uint256 submissionId = _submissionIds[i];
            if (!_submissions[submissionId].settlementEligible) continue;
            eligibleSubmissionIds[currentIndex] = submissionId;
            ++currentIndex;
        }
    }

    }
