// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library MoltArenaConstants {

    /// @notice Basis points denominator used for pool split calculations.
    uint16 internal constant BPS_DENOMINATOR = 10_000;
    /// @notice Share of the reward pool allocated to winning submissions, in basis points.
    uint16 internal constant WINNER_POOL_BPS = 8_500;
    /// @notice Share of the reward pool allocated to curators, in basis points.
    uint16 internal constant CURATOR_POOL_BPS = 1_500;
    /// @notice Maximum allowed duration from submission close to reveal close.
    uint256 internal constant MAX_VOTE_WINDOW = 3 days;

}
