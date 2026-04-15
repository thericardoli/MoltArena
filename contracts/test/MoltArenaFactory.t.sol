// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

import { MoltArenaBounty } from "../src/MoltArenaBounty.sol";
import { MoltArenaFactory } from "../src/MoltArenaFactory.sol";
import { IMoltArenaBounty } from "../src/interfaces/IMoltArenaBounty.sol";
import { MoltArenaTypes } from "../src/libraries/MoltArenaTypes.sol";
import { MoltArenaVoteToken } from "../src/token/MoltArenaVoteToken.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract BountyFactoryCaller {

    function approveAndCreate(
        MockERC20 rewardToken,
        MoltArenaFactory factory,
        uint256 rewardAmount,
        MoltArenaTypes.CreateBountyParams calldata params
    ) external returns (uint256 bountyId, address bountyAddress) {
        rewardToken.approve(address(factory), rewardAmount);
        return factory.createBounty(params);
    }

}

contract MoltArenaFactoryTest is Test {

    address internal constant WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;

    MockERC20 internal rewardToken;
    MoltArenaVoteToken internal voteToken;
    MoltArenaBounty internal bountyImplementation;
    MoltArenaFactory internal factory;

    address internal creator = address(0xA11CE);
    address internal solver = address(0xB0B);
    address internal other = address(0xCAFE);
    address internal voterTwo = address(0xD00D);
    address internal voterThree = address(0xF00D);
    BountyFactoryCaller internal relay;

    function setUp() public {
        vm.warp(1_000_000);

        MockERC20 rewardTokenTemplate = new MockERC20("Wrapped OKB", "WOKB");
        vm.etch(WOKB, address(rewardTokenTemplate).code);
        rewardToken = MockERC20(WOKB);
        voteToken = new MoltArenaVoteToken("MoltArena Vote", "MAV", 1 days, 100e18);
        bountyImplementation = new MoltArenaBounty();
        factory = new MoltArenaFactory(address(bountyImplementation), voteToken);
        relay = new BountyFactoryCaller();

        voteToken.grantRole(voteToken.CONSUMER_MANAGER_ROLE(), address(factory));
        rewardToken.mint(creator, 1_000_000e18);
    }

    function testCreateBountyDeploysCloneStoresPoolsAndFundsClone() public {
        MoltArenaTypes.CreateBountyParams memory params = _defaultBountyParams();

        vm.startPrank(creator, creator);
        rewardToken.approve(address(factory), params.rewardAmount);
        uint256 bountyId;
        address bountyAddress;
        (bountyId, bountyAddress) = factory.createBounty(params);
        vm.stopPrank();

        IMoltArenaBounty bounty = IMoltArenaBounty(bountyAddress);
        MoltArenaTypes.Bounty memory data = bounty.getBounty();

        assertEq(bountyId, 1);
        assertEq(factory.bountyCount(), 1);
        assertEq(factory.getBountyAddress(1), bountyAddress);
        assertTrue(factory.isBounty(bountyAddress));
        assertTrue(voteToken.hasRole(voteToken.CONSUMER_ROLE(), bountyAddress));
        assertEq(address(factory.rewardToken()), WOKB);
        assertEq(data.bountyId, 1);
        assertEq(data.creator, creator);
        assertEq(data.settlementVerifier, creator);
        assertEq(data.metadataURI, params.metadataURI);
        assertEq(data.settlementScopeHash, params.settlementScopeHash);
        assertEq(data.rewardAmount, params.rewardAmount);
        assertEq(data.winnerPool, 85e18);
        assertEq(data.curatorPool, 15e18);
        assertEq(data.maxVoteCreditsPerVoter, params.maxVoteCreditsPerVoter);
        assertEq(uint256(data.winnerCount), 2);
        assertEq(uint256(data.eligibleSubmissionCount), 0);
        assertEq(uint256(data.status), uint256(MoltArenaTypes.BountyStatus.SubmissionOpen));
        assertEq(rewardToken.balanceOf(bountyAddress), params.rewardAmount);
    }

    function testCreateBountySetsCreatorToTxOrigin() public {
        MoltArenaTypes.CreateBountyParams memory params = _defaultBountyParams();
        rewardToken.mint(address(relay), params.rewardAmount);

        vm.prank(creator, creator);
        (, address bountyAddress) = relay.approveAndCreate(rewardToken, factory, params.rewardAmount, params);

        MoltArenaTypes.Bounty memory data = IMoltArenaBounty(bountyAddress).getBounty();

        assertEq(data.creator, creator);
        assertTrue(data.creator != address(relay));
        assertEq(data.settlementVerifier, creator);
        assertEq(rewardToken.balanceOf(bountyAddress), params.rewardAmount);
    }

    function testCreateBountyRejectsZeroPerVoterVoteCap() public {
        MoltArenaTypes.CreateBountyParams memory params = _defaultBountyParams();
        params.maxVoteCreditsPerVoter = 0;

        vm.startPrank(creator, creator);
        rewardToken.approve(address(factory), params.rewardAmount);
        vm.expectRevert(IMoltArenaBounty.MaxVoteCreditsPerVoterZero.selector);
        factory.createBounty(params);
        vm.stopPrank();
    }

    function testCreateBountyRejectsInvalidDeadlineOrder() public {
        MoltArenaTypes.CreateBountyParams memory params = _defaultBountyParams();
        params.commitDeadline = params.submissionDeadline;

        vm.startPrank(creator, creator);
        rewardToken.approve(address(factory), params.rewardAmount);
        vm.expectRevert(IMoltArenaBounty.InvalidDeadlineOrder.selector);
        factory.createBounty(params);
        vm.stopPrank();
    }

    function testCreateBountyRejectsVoteWindowLongerThanMax() public {
        MoltArenaTypes.CreateBountyParams memory params = _defaultBountyParams();
        params.revealDeadline = params.submissionDeadline + uint40(4 days);

        vm.startPrank(creator, creator);
        rewardToken.approve(address(factory), params.rewardAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMoltArenaBounty.VoteWindowTooLong.selector, 4 days, bountyImplementation.maxVoteWindow()
            )
        );
        factory.createBounty(params);
        vm.stopPrank();
    }

    function testFactoryGetBountyAddressesReturnsPaginatedResults() public {
        _createDefaultBounty();
        vm.warp(block.timestamp + 1);
        _createDefaultBounty();
        vm.warp(block.timestamp + 1);
        _createDefaultBounty();

        address[] memory bountyAddresses = factory.getBountyAddresses(2, 2);

        assertEq(bountyAddresses.length, 2);
        assertTrue(factory.isBounty(bountyAddresses[0]));
        assertTrue(factory.isBounty(bountyAddresses[1]));
    }

    function testSubmitSolutionStoresContentAndTimestamp() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        uint256 submissionId = bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        MoltArenaTypes.Submission memory submission = bounty.getSubmission(submissionId);

        assertEq(submissionId, 1);
        assertEq(submission.submitter, solver);
        assertEq(submission.postURL, "https://www.moltbook.com/post/solver-1");
        assertEq(submission.contentHash, keccak256("solver-1"));
        assertEq(uint256(submission.submittedAt), block.timestamp);
        assertTrue(bounty.hasSubmitted(solver));
    }

    function testSubmitSolutionRejectsSecondSubmissionFromSameAddress() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.startPrank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));
        vm.expectRevert(abi.encodeWithSelector(IMoltArenaBounty.SubmissionAlreadyExists.selector, 1, solver));
        bounty.submitSolution("https://www.moltbook.com/post/solver-2", keccak256("solver-2"));
        vm.stopPrank();
    }

    function testSubmitSolutionRejectsEmptyPostUrl() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        vm.expectRevert(IMoltArenaBounty.InvalidMoltbookReference.selector);
        bounty.submitSolution("", keccak256("solver-1"));
    }

    function testSubmitSolutionRejectsAfterSubmissionDeadline() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();
        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();

        vm.warp(bountyData.submissionDeadline);
        vm.prank(solver);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMoltArenaBounty.BountyPhaseMismatch.selector,
                bountyData.bountyId,
                MoltArenaTypes.BountyStatus.SubmissionOpen,
                MoltArenaTypes.BountyStatus.CommitOpen
            )
        );
        bounty.submitSolution("https://www.moltbook.com/post/late", keccak256("late"));
    }

    function testGetSubmissionIdsReturnsRegisteredIds() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.prank(other);
        bounty.submitSolution("https://www.moltbook.com/post/solver-2", keccak256("solver-2"));

        uint256[] memory ids = bounty.getSubmissionIds();

        assertEq(ids.length, 2);
        assertEq(ids[0], 1);
        assertEq(ids[1], 2);
    }

    function testSetSubmissionEligibilityUpdatesEligibilityState() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        uint256 submissionId = bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        MoltArenaTypes.Submission memory initialSubmission = bounty.getSubmission(submissionId);
        assertTrue(initialSubmission.settlementEligible);
        assertEq(uint256(bounty.getBounty().eligibleSubmissionCount), 1);

        vm.prank(creator);
        bounty.setSubmissionEligibility(submissionId, false, keccak256("out-of-scope"));

        MoltArenaTypes.Submission memory updatedSubmission = bounty.getSubmission(submissionId);
        assertFalse(updatedSubmission.settlementEligible);
        assertEq(updatedSubmission.eligibilityContextHash, keccak256("out-of-scope"));
        assertEq(uint256(bounty.getBounty().eligibleSubmissionCount), 0);
    }

    function testSetSubmissionEligibilityRejectsNonVerifier() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        uint256 submissionId = bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(IMoltArenaBounty.NotSettlementVerifier.selector, 1, other, creator));
        bounty.setSubmissionEligibility(submissionId, false, keccak256("no-auth"));
    }

    function testCommitVoteConsumesBalanceAndStoresCommit() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.prank(other);
        voteToken.claim();
        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();
        vm.warp(bountyData.submissionDeadline);

        bytes32 commitHash = keccak256("commit-1");
        vm.prank(other);
        bounty.commitVote(commitHash, 10e18);

        MoltArenaTypes.VoteCommit memory voteCommit = bounty.getVoteCommit(other);
        assertEq(voteCommit.commitHash, commitHash);
        assertEq(voteCommit.lockedCredits, 10e18);
        assertEq(voteToken.balanceOf(other), 90e18);
    }

    function testCommitVoteRejectsDuplicateCommit() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.prank(other);
        voteToken.claim();
        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();
        vm.warp(bountyData.submissionDeadline);

        vm.startPrank(other);
        bounty.commitVote(keccak256("commit-1"), 10e18);
        vm.expectRevert(
            abi.encodeWithSelector(IMoltArenaBounty.VoteAlreadyCommitted.selector, bountyData.bountyId, other)
        );
        bounty.commitVote(keccak256("commit-2"), 5e18);
        vm.stopPrank();
    }

    function testCommitVoteRejectsPerAddressVoteCap() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.prank(other);
        voteToken.claim();
        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();
        vm.warp(bountyData.submissionDeadline);

        vm.prank(other);
        vm.expectRevert(
            abi.encodeWithSelector(IMoltArenaBounty.VotePerAddressCapExceeded.selector, 1, other, 16e18, 15e18)
        );
        bounty.commitVote(keccak256("commit-cap"), 16e18);
    }

    function testRevealVoteCountsVotesAndMarksCommitRevealed() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.prank(creator);
        bounty.submitSolution("https://www.moltbook.com/post/creator-1", keccak256("creator-1"));

        vm.prank(other);
        voteToken.claim();
        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();
        vm.warp(bountyData.submissionDeadline);

        uint256[] memory submissionIds = new uint256[](2);
        submissionIds[0] = 1;
        submissionIds[1] = 2;
        uint96[] memory credits = new uint96[](2);
        credits[0] = 4e18;
        credits[1] = 6e18;
        bytes32 salt = keccak256("salt-1");
        bytes32 commitHash = bounty.hashVoteAllocation(other, submissionIds, credits, salt);

        vm.prank(other);
        bounty.commitVote(commitHash, 10e18);

        vm.warp(bountyData.commitDeadline);
        vm.prank(other);
        bounty.revealVote(
            MoltArenaTypes.RevealVoteParams({ submissionIds: submissionIds, credits: credits, salt: salt })
        );

        MoltArenaTypes.VoteCommit memory voteCommit = bounty.getVoteCommit(other);
        MoltArenaTypes.Submission memory first = bounty.getSubmission(1);
        MoltArenaTypes.Submission memory second = bounty.getSubmission(2);

        assertTrue(voteCommit.revealed);
        assertEq(voteCommit.revealedCredits, 10e18);
        assertEq(first.finalVotes, 4e18);
        assertEq(second.finalVotes, 6e18);
    }

    function testRevealVoteRejectsSelfVote() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));
        vm.prank(solver);
        voteToken.claim();

        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();
        vm.warp(bountyData.submissionDeadline);

        uint256[] memory submissionIds = new uint256[](1);
        submissionIds[0] = 1;
        uint96[] memory credits = new uint96[](1);
        credits[0] = 10e18;
        bytes32 salt = keccak256("salt-1");
        bytes32 commitHash = bounty.hashVoteAllocation(solver, submissionIds, credits, salt);

        vm.prank(solver);
        bounty.commitVote(commitHash, 10e18);

        vm.warp(bountyData.commitDeadline);
        vm.prank(solver);
        vm.expectRevert(
            abi.encodeWithSelector(IMoltArenaBounty.SelfVoteNotAllowed.selector, bountyData.bountyId, solver, 1)
        );
        bounty.revealVote(
            MoltArenaTypes.RevealVoteParams({ submissionIds: submissionIds, credits: credits, salt: salt })
        );
    }

    function testRevealVoteRejectsIneligibleSubmission() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.prank(creator);
        bounty.submitSolution("https://www.moltbook.com/post/creator-1", keccak256("creator-1"));

        vm.prank(creator);
        bounty.setSubmissionEligibility(2, false, keccak256("fails-scope"));

        vm.prank(other);
        voteToken.claim();
        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();
        vm.warp(bountyData.submissionDeadline);

        uint256[] memory submissionIds = new uint256[](2);
        submissionIds[0] = 1;
        submissionIds[1] = 2;
        uint96[] memory credits = new uint96[](2);
        credits[0] = 4e18;
        credits[1] = 6e18;
        bytes32 salt = keccak256("salt-1");
        bytes32 commitHash = bounty.hashVoteAllocation(other, submissionIds, credits, salt);

        vm.prank(other);
        bounty.commitVote(commitHash, 10e18);

        vm.warp(bountyData.commitDeadline);
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(IMoltArenaBounty.SubmissionNotEligible.selector, 1, 2));
        bounty.revealVote(
            MoltArenaTypes.RevealVoteParams({ submissionIds: submissionIds, credits: credits, salt: salt })
        );
    }

    function testFinalizeBountyMarksTopWinnersAfterRevealPeriod() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.prank(creator);
        bounty.submitSolution("https://www.moltbook.com/post/creator-1", keccak256("creator-1"));

        vm.prank(address(0xD00D));
        bounty.submitSolution("https://www.moltbook.com/post/third-1", keccak256("third-1"));

        vm.prank(other);
        voteToken.claim();
        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();
        vm.warp(bountyData.submissionDeadline);

        uint256[] memory submissionIds = new uint256[](2);
        submissionIds[0] = 2;
        submissionIds[1] = 3;
        uint96[] memory credits = new uint96[](2);
        credits[0] = 6e18;
        credits[1] = 4e18;
        bytes32 salt = keccak256("salt-1");
        bytes32 commitHash = bounty.hashVoteAllocation(other, submissionIds, credits, salt);

        vm.prank(other);
        bounty.commitVote(commitHash, 10e18);

        vm.warp(bountyData.commitDeadline);
        vm.prank(other);
        bounty.revealVote(
            MoltArenaTypes.RevealVoteParams({ submissionIds: submissionIds, credits: credits, salt: salt })
        );

        vm.warp(bountyData.revealDeadline);
        bounty.finalizeBounty();

        MoltArenaTypes.Bounty memory finalized = bounty.getBounty();
        uint256[] memory winnerIds = bounty.getWinnerSubmissionIds();

        assertEq(uint256(finalized.status), uint256(MoltArenaTypes.BountyStatus.Finalized));
        assertTrue(finalized.finalized);
        assertEq(uint256(finalized.finalizedWinnerCount), 2);
        assertEq(uint256(finalized.validRevealCount), 1);
        assertEq(winnerIds.length, 2);
        assertEq(winnerIds[0], 2);
        assertEq(winnerIds[1], 3);
    }

    function testFinalizeBountyBreaksTiesByEarlierSubmission() public {
        MoltArenaTypes.CreateBountyParams memory params = _defaultBountyParams();
        params.winnerCount = 1;

        (uint256 bountyId, IMoltArenaBounty bounty) = _createBounty(params);

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.warp(block.timestamp + 5);
        vm.prank(other);
        bounty.submitSolution("https://www.moltbook.com/post/other-1", keccak256("other-1"));

        vm.prank(creator);
        voteToken.claim();
        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();
        vm.warp(bountyData.submissionDeadline);

        uint256[] memory submissionIds = new uint256[](2);
        submissionIds[0] = 1;
        submissionIds[1] = 2;
        uint96[] memory credits = new uint96[](2);
        credits[0] = 5e18;
        credits[1] = 5e18;
        bytes32 salt = keccak256("salt-1");
        bytes32 commitHash = bounty.hashVoteAllocation(creator, submissionIds, credits, salt);

        vm.prank(creator);
        bounty.commitVote(commitHash, 10e18);

        vm.warp(bountyData.commitDeadline);
        vm.prank(creator);
        bounty.revealVote(
            MoltArenaTypes.RevealVoteParams({ submissionIds: submissionIds, credits: credits, salt: salt })
        );

        vm.warp(bountyData.revealDeadline);
        bounty.finalizeBounty();

        MoltArenaTypes.Submission memory first = bounty.getSubmission(1);
        MoltArenaTypes.Submission memory second = bounty.getSubmission(2);

        assertEq(bountyId, 1);
        assertTrue(first.winner);
        assertFalse(second.winner);
    }

    function testFinalizeBountyRanksOnlyEligibleSubmissions() public {
        MoltArenaTypes.CreateBountyParams memory params = _defaultBountyParams();
        params.winnerCount = 3;

        (, IMoltArenaBounty bounty) = _createBounty(params);

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));
        vm.prank(creator);
        bounty.submitSolution("https://www.moltbook.com/post/creator-1", keccak256("creator-1"));
        vm.prank(voterTwo);
        bounty.submitSolution("https://www.moltbook.com/post/voter-two-1", keccak256("voter-two-1"));

        vm.prank(creator);
        bounty.setSubmissionEligibility(3, false, keccak256("excluded"));

        vm.prank(other);
        voteToken.claim();
        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();
        vm.warp(bountyData.submissionDeadline);

        uint256[] memory submissionIds = new uint256[](2);
        submissionIds[0] = 1;
        submissionIds[1] = 2;
        uint96[] memory credits = new uint96[](2);
        credits[0] = 4e18;
        credits[1] = 6e18;
        bytes32 salt = keccak256("eligible-only");
        bytes32 commitHash = bounty.hashVoteAllocation(other, submissionIds, credits, salt);

        vm.prank(other);
        bounty.commitVote(commitHash, 10e18);

        vm.warp(bountyData.commitDeadline);
        vm.prank(other);
        bounty.revealVote(
            MoltArenaTypes.RevealVoteParams({ submissionIds: submissionIds, credits: credits, salt: salt })
        );

        vm.warp(bountyData.revealDeadline);
        bounty.finalizeBounty();

        MoltArenaTypes.Bounty memory finalized = bounty.getBounty();
        uint256[] memory winnerIds = bounty.getWinnerSubmissionIds();

        assertEq(uint256(finalized.eligibleSubmissionCount), 2);
        assertEq(uint256(finalized.finalizedWinnerCount), 2);
        assertEq(winnerIds.length, 2);
        assertEq(winnerIds[0], 2);
        assertEq(winnerIds[1], 1);
    }

    function testClaimWinnerRewardPaysEqualShareAndRejectsDoubleClaim() public {
        (, IMoltArenaBounty bounty) = _createFinalizedTwoWinnerBounty();

        uint256 creatorBalanceBefore = rewardToken.balanceOf(creator);
        uint256 voterTwoBalanceBefore = rewardToken.balanceOf(voterTwo);

        vm.prank(creator);
        uint256 creatorReward = bounty.claimWinnerReward();
        vm.prank(voterTwo);
        uint256 voterTwoWinnerReward = bounty.claimWinnerReward();

        assertEq(creatorReward, 42.5e18);
        assertEq(voterTwoWinnerReward, 42.5e18);
        assertEq(rewardToken.balanceOf(creator), creatorBalanceBefore + 42.5e18);
        assertEq(rewardToken.balanceOf(voterTwo), voterTwoBalanceBefore + 42.5e18);

        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(IMoltArenaBounty.RewardAlreadyClaimed.selector, 1, creator));
        bounty.claimWinnerReward();
    }

    function testClaimCuratorRewardPaysWeightedShare() public {
        (, IMoltArenaBounty bounty) = _createFinalizedTwoWinnerBounty();

        uint256 otherBalanceBefore = rewardToken.balanceOf(other);
        uint256 voterThreeBalanceBefore = rewardToken.balanceOf(voterThree);

        vm.prank(other);
        uint256 otherReward = bounty.claimCuratorReward();
        vm.prank(voterThree);
        uint256 voterThreeReward = bounty.claimCuratorReward();

        assertEq(otherReward, 9e18);
        assertEq(voterThreeReward, 6e18);
        assertEq(rewardToken.balanceOf(other), otherBalanceBefore + 9e18);
        assertEq(rewardToken.balanceOf(voterThree), voterThreeBalanceBefore + 6e18);
    }

    function testClaimableRewardsReturnsWinnerAndCuratorAmounts() public {
        (, IMoltArenaBounty bounty) = _createFinalizedTwoWinnerBounty();

        MoltArenaTypes.ClaimableRewards memory creatorRewards = bounty.claimableRewards(creator);
        MoltArenaTypes.ClaimableRewards memory otherRewards = bounty.claimableRewards(other);

        assertEq(creatorRewards.winnerReward, 42.5e18);
        assertEq(creatorRewards.curatorReward, 0);
        assertEq(otherRewards.winnerReward, 0);
        assertEq(otherRewards.curatorReward, 9e18);
    }

    function testFinalizeBountyRefundsCreatorWhenThereAreNoSubmissions() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();
        uint256 balanceAfterFunding = rewardToken.balanceOf(creator);
        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();

        vm.warp(bountyData.revealDeadline);
        bounty.finalizeBounty();

        assertEq(rewardToken.balanceOf(creator), balanceAfterFunding + 100e18);
        assertEq(rewardToken.balanceOf(address(bounty)), 0);
        assertEq(uint256(bounty.getBounty().status), uint256(MoltArenaTypes.BountyStatus.Finalized));
        assertTrue(bounty.getBounty().finalized);
        assertEq(uint256(bounty.getBounty().finalizedWinnerCount), 0);
    }

    function testFinalizeBountyRefundsCreatorWhenAllSubmissionsBecomeIneligible() public {
        (, IMoltArenaBounty bounty) = _createDefaultBounty();

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.prank(creator);
        bounty.setSubmissionEligibility(1, false, keccak256("scope-failed"));

        uint256 balanceAfterFunding = rewardToken.balanceOf(creator);
        vm.warp(bounty.getBounty().revealDeadline);

        bounty.finalizeBounty();

        assertEq(rewardToken.balanceOf(creator), balanceAfterFunding + 100e18);
        assertEq(rewardToken.balanceOf(address(bounty)), 0);
        assertEq(uint256(bounty.getBounty().status), uint256(MoltArenaTypes.BountyStatus.Finalized));
        assertTrue(bounty.getBounty().finalized);
        assertEq(uint256(bounty.getBounty().finalizedWinnerCount), 0);
    }

    function _createDefaultBounty() internal returns (uint256 bountyId, IMoltArenaBounty bounty) {
        return _createBounty(_defaultBountyParams());
    }

    function _createBounty(
        MoltArenaTypes.CreateBountyParams memory params
    ) internal returns (uint256 bountyId, IMoltArenaBounty bounty) {
        vm.startPrank(creator, creator);
        rewardToken.approve(address(factory), params.rewardAmount);
        address bountyAddress;
        (bountyId, bountyAddress) = factory.createBounty(params);
        vm.stopPrank();

        bounty = IMoltArenaBounty(bountyAddress);
    }

    function _createFinalizedTwoWinnerBounty() internal returns (uint256 bountyId, IMoltArenaBounty bounty) {
        (bountyId, bounty) = _createDefaultBounty();

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.prank(creator);
        bounty.submitSolution("https://www.moltbook.com/post/creator-1", keccak256("creator-1"));

        vm.prank(voterTwo);
        bounty.submitSolution("https://www.moltbook.com/post/voter-two-1", keccak256("voter-two-1"));

        MoltArenaTypes.Bounty memory bountyData = bounty.getBounty();
        vm.warp(bountyData.submissionDeadline);

        vm.prank(other);
        voteToken.claim();
        vm.prank(voterThree);
        voteToken.claim();

        uint256[] memory otherSubmissionIds = new uint256[](3);
        otherSubmissionIds[0] = 1;
        otherSubmissionIds[1] = 2;
        otherSubmissionIds[2] = 3;
        uint96[] memory otherCredits = new uint96[](3);
        otherCredits[0] = 3e18;
        otherCredits[1] = 8e18;
        otherCredits[2] = 4e18;
        bytes32 otherSalt = keccak256("other-salt");
        bytes32 otherCommitHash = bounty.hashVoteAllocation(other, otherSubmissionIds, otherCredits, otherSalt);

        vm.prank(other);
        bounty.commitVote(otherCommitHash, 15e18);

        uint256[] memory voterThreeSubmissionIds = new uint256[](3);
        voterThreeSubmissionIds[0] = 1;
        voterThreeSubmissionIds[1] = 2;
        voterThreeSubmissionIds[2] = 3;
        uint96[] memory voterThreeCredits = new uint96[](3);
        voterThreeCredits[0] = 2e18;
        voterThreeCredits[1] = 2e18;
        voterThreeCredits[2] = 6e18;
        bytes32 voterThreeSalt = keccak256("voter-three-salt");
        bytes32 voterThreeCommitHash =
            bounty.hashVoteAllocation(voterThree, voterThreeSubmissionIds, voterThreeCredits, voterThreeSalt);

        vm.prank(voterThree);
        bounty.commitVote(voterThreeCommitHash, 10e18);

        vm.warp(bountyData.commitDeadline);

        vm.prank(other);
        bounty.revealVote(
            MoltArenaTypes.RevealVoteParams({
                submissionIds: otherSubmissionIds,
                credits: otherCredits,
                salt: otherSalt
            })
        );

        vm.prank(voterThree);
        bounty.revealVote(
            MoltArenaTypes.RevealVoteParams({
                submissionIds: voterThreeSubmissionIds,
                credits: voterThreeCredits,
                salt: voterThreeSalt
            })
        );

        vm.warp(bountyData.revealDeadline);
        bounty.finalizeBounty();
    }

    function _defaultBountyParams() internal view returns (MoltArenaTypes.CreateBountyParams memory) {
        return MoltArenaTypes.CreateBountyParams({
            metadataURI: "ipfs://moltarena/bounty/1",
            settlementScopeHash: keccak256("settlement-scope-v1"),
            settlementVerifier: address(0),
            rewardAmount: 100e18,
            maxVoteCreditsPerVoter: 15e18,
            winnerCount: 2,
            submissionDeadline: uint40(block.timestamp + 1 days),
            commitDeadline: uint40(block.timestamp + 2 days),
            revealDeadline: uint40(block.timestamp + 3 days)
        });
    }

}
