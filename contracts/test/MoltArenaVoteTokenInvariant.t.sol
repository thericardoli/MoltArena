// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";

import { MoltArenaVoteToken } from "../src/token/MoltArenaVoteToken.sol";

contract MoltArenaVoteTokenInvariantHandler is Test {

    MoltArenaVoteToken internal immutable voteToken;
    address internal immutable claimer;

    bool internal _claimerHasClaimed;
    uint256 internal _claimedBalance;

    constructor(
        MoltArenaVoteToken voteToken_,
        address claimer_
    ) {
        voteToken = voteToken_;
        claimer = claimer_;
    }

    function claimForClaimer() external {
        vm.prank(claimer);
        (bool ok,) = address(voteToken).call(abi.encodeCall(MoltArenaVoteToken.claim, ()));
        if (ok && !_claimerHasClaimed) {
            _claimerHasClaimed = true;
            _claimedBalance = voteToken.balanceOf(claimer);
        }
    }

    function claimForOther(
        uint256 seed
    ) external {
        address other = _nonClaimerAddress(seed);
        vm.prank(other);
        address(voteToken).call(abi.encodeCall(MoltArenaVoteToken.claim, ()));
    }

    function grantConsumerOther(
        uint256 seed
    ) external {
        voteToken.grantConsumer(_nonClaimerAddress(seed));
    }

    function revokeConsumerOther(
        uint256 seed
    ) external {
        voteToken.revokeConsumer(_nonClaimerAddress(seed));
    }

    function consumeOther(
        uint256 seed,
        uint256 amount
    ) external {
        address other = _nonClaimerAddress(seed);
        vm.prank(other);
        address(voteToken).call(abi.encodeCall(MoltArenaVoteToken.claim, ()));
        voteToken.consume(other, bound(amount, 1, voteToken.claimAmountPerEpoch()));
    }

    function claimerHasClaimed() external view returns (bool) {
        return _claimerHasClaimed;
    }

    function claimedBalance() external view returns (uint256) {
        return _claimedBalance;
    }

    function _nonClaimerAddress(
        uint256 seed
    ) internal view returns (address derived) {
        derived = address(uint160(uint256(keccak256(abi.encode(seed, address(this))))));
        if (derived == address(0) || derived == claimer) {
            derived = address(uint160(uint256(keccak256(abi.encode(seed, claimer, "fallback")))));
        }
    }

}

contract MoltArenaVoteTokenInvariantTest is StdInvariant, Test {

    MoltArenaVoteToken internal voteToken;
    MoltArenaVoteTokenInvariantHandler internal handler;

    address internal claimer = address(0xCAFE);

    function setUp() public {
        vm.warp(1_000_000);

        voteToken = new MoltArenaVoteToken("MoltArena Vote", "MAV", 1 days, 100e18);
        handler = new MoltArenaVoteTokenInvariantHandler(voteToken, claimer);
        voteToken.grantRole(voteToken.CONSUMER_MANAGER_ROLE(), address(handler));
        voteToken.grantConsumer(address(handler));

        targetContract(address(handler));
    }

    function invariant_ClaimedBalanceStaysConstantWithinSameEpoch() public view {
        if (!handler.claimerHasClaimed()) return;

        assertEq(voteToken.balanceOf(claimer), handler.claimedBalance());
        assertEq(voteToken.balanceOf(claimer), 100e18);
        assertEq(voteToken.lastClaimedEpoch(claimer), 1);
        assertEq(voteToken.currentEpoch(), 1);
    }

}
