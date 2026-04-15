// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

import { MoltArenaBounty } from "../src/MoltArenaBounty.sol";
import { MoltArenaFactory } from "../src/MoltArenaFactory.sol";
import { MoltArenaLens } from "../src/MoltArenaLens.sol";
import { IMoltArenaBounty } from "../src/interfaces/IMoltArenaBounty.sol";
import { MoltArenaTypes } from "../src/libraries/MoltArenaTypes.sol";
import { MoltArenaVoteToken } from "../src/token/MoltArenaVoteToken.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract MoltArenaLensTest is Test {

    address internal constant WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;

    MockERC20 internal rewardToken;
    MoltArenaVoteToken internal voteToken;
    MoltArenaBounty internal bountyImplementation;
    MoltArenaFactory internal factory;
    MoltArenaLens internal lens;

    address internal creator = address(0xA11CE);
    address internal solver = address(0xB0B);
    address internal voter = address(0xCAFE);

    function setUp() public {
        vm.warp(1_000_000);

        MockERC20 rewardTokenTemplate = new MockERC20("Wrapped OKB", "WOKB");
        vm.etch(WOKB, address(rewardTokenTemplate).code);
        rewardToken = MockERC20(WOKB);
        voteToken = new MoltArenaVoteToken("MoltArena Vote", "MAV", 1 days, 100e18);
        bountyImplementation = new MoltArenaBounty();
        factory = new MoltArenaFactory(address(bountyImplementation), voteToken);
        lens = new MoltArenaLens(factory);

        voteToken.grantRole(voteToken.CONSUMER_MANAGER_ROLE(), address(factory));
        rewardToken.mint(creator, 1_000_000e18);
    }

    function testGetBountyAddressMatchesFactoryRegistry() public {
        (uint256 bountyId, address bountyAddress) = _createDefaultBounty();

        assertEq(lens.getBountyAddress(bountyId), bountyAddress);
    }

    function testGetBountiesReturnsAggregatedCloneData() public {
        _createDefaultBounty();
        vm.warp(block.timestamp + 1);
        _createDefaultBounty();

        MoltArenaTypes.Bounty[] memory bounties = lens.getBounties(1, 2);

        assertEq(bounties.length, 2);
        assertEq(bounties[0].bountyId, 1);
        assertEq(bounties[1].bountyId, 2);
        assertEq(bounties[0].creator, creator);
        assertEq(bounties[1].creator, creator);
    }

    function testCurrentStatusMatchesBountyClone() public {
        (uint256 bountyId,) = _createDefaultBounty();

        assertEq(uint256(lens.currentStatus(bountyId)), uint256(MoltArenaTypes.BountyStatus.SubmissionOpen));
    }

    function testGetBountyTimingReturnsCloneDeadlines() public {
        (uint256 bountyId, address bountyAddress) = _createDefaultBounty();
        MoltArenaTypes.Bounty memory bounty = IMoltArenaBounty(bountyAddress).getBounty();

        MoltArenaTypes.BountyTiming memory timing = lens.getBountyTiming(bountyId);

        assertEq(uint256(timing.submissionDeadline), uint256(bounty.submissionDeadline));
        assertEq(uint256(timing.voteDeadline), uint256(bounty.voteDeadline));
    }

    function testGetSubmissionIdsReflectsCloneRegistration() public {
        (uint256 bountyId, address bountyAddress) = _createDefaultBounty();
        IMoltArenaBounty bounty = IMoltArenaBounty(bountyAddress);

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        uint256[] memory ids = lens.getSubmissionIds(bountyId);

        assertEq(ids.length, 1);
        assertEq(ids[0], 1);
    }

    function testGetEligibleSubmissionIdsReflectsEligibilityUpdates() public {
        (uint256 bountyId, address bountyAddress) = _createDefaultBounty();
        IMoltArenaBounty bounty = IMoltArenaBounty(bountyAddress);

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));

        vm.prank(creator);
        bounty.submitSolution("https://www.moltbook.com/post/creator-1", keccak256("creator-1"));

        vm.prank(creator);
        bounty.setSubmissionEligibility(2, false, keccak256("fails-scope"));

        uint256[] memory ids = lens.getEligibleSubmissionIds(bountyId);

        assertEq(ids.length, 1);
        assertEq(ids[0], 1);
    }

    function testAvailableVoteCreditsReturnsZeroAfterVote() public {
        (uint256 bountyId, address bountyAddress) = _createDefaultBounty();
        IMoltArenaBounty bounty = IMoltArenaBounty(bountyAddress);

        vm.prank(solver);
        bounty.submitSolution("https://www.moltbook.com/post/solver-1", keccak256("solver-1"));
        vm.prank(creator);
        bounty.submitSolution("https://www.moltbook.com/post/creator-1", keccak256("creator-1"));

        vm.prank(voter);
        voteToken.claim();
        assertEq(lens.availableVoteCredits(voter, bountyId), 15e18);

        vm.warp(bounty.getBounty().submissionDeadline);
        uint256[] memory submissionIds = new uint256[](1);
        submissionIds[0] = 1;
        uint96[] memory credits = new uint96[](1);
        credits[0] = 10e18;

        vm.prank(voter);
        bounty.vote(submissionIds, credits);

        assertEq(lens.availableVoteCredits(voter, bountyId), 0);
        assertEq(lens.usedVoteCredits(voter, bountyId), 10e18);
    }

    function _createDefaultBounty() internal returns (uint256 bountyId, address bountyAddress) {
        MoltArenaTypes.CreateBountyParams memory params = MoltArenaTypes.CreateBountyParams({
            metadataURI: "ipfs://moltarena/bounty/1",
            settlementScopeHash: keccak256("settlement-scope-v1"),
            settlementVerifier: address(0),
            rewardAmount: 100e18,
            maxVoteCreditsPerVoter: 15e18,
            winnerCount: 2,
            submissionDeadline: uint40(block.timestamp + 1 days),
            voteDeadline: uint40(block.timestamp + 2 days)
        });

        vm.startPrank(creator, creator);
        rewardToken.approve(address(factory), params.rewardAmount);
        (bountyId, bountyAddress) = factory.createBounty(params);
        vm.stopPrank();
    }

}
