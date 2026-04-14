// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

import { IMoltArenaVoteToken } from "../src/interfaces/IMoltArenaVoteToken.sol";
import { MoltArenaVoteToken } from "../src/token/MoltArenaVoteToken.sol";

contract MoltArenaVoteTokenTest is Test {

    MoltArenaVoteToken internal voteToken;
    address internal claimer = address(0xCAFE);

    function setUp() public {
        vm.warp(1_000_000);
        voteToken = new MoltArenaVoteToken("MoltArena Vote", "MAV", 1 days, 100e18);
    }

    function testDecimalsUseOpenZeppelinDefault() public view {
        assertEq(voteToken.decimals(), 18);
    }

    function testClaimMintsPerEpochAmount() public {
        vm.prank(claimer);
        voteToken.claim();

        assertEq(voteToken.balanceOf(claimer), 100e18);
        assertEq(voteToken.currentEpoch(), 1);
    }

    function testClaimCannotBeRepeatedWithinSameEpoch() public {
        vm.startPrank(claimer);
        voteToken.claim();
        vm.expectRevert(abi.encodeWithSelector(IMoltArenaVoteToken.AlreadyClaimedForEpoch.selector, claimer, 1));
        voteToken.claim();
        vm.stopPrank();

        assertEq(voteToken.balanceOf(claimer), 100e18);
        assertEq(voteToken.lastClaimedEpoch(claimer), 1);
    }

    function testClaimCanBeRepeatedAfterEpochChanges() public {
        vm.startPrank(claimer);
        voteToken.claim();
        vm.warp(block.timestamp + 1 days);
        voteToken.claim();
        vm.stopPrank();

        assertEq(voteToken.balanceOf(claimer), 200e18);
        assertEq(voteToken.lastClaimedEpoch(claimer), 2);
    }

}
