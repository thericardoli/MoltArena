// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { MoltArenaTypes } from "../libraries/MoltArenaTypes.sol";

interface IMoltArenaLens {

    function getBountyAddress(
        uint256 bountyId
    ) external view returns (address bounty);

    function currentStatus(
        uint256 bountyId
    ) external view returns (MoltArenaTypes.BountyStatus);

    function getBounty(
        uint256 bountyId
    ) external view returns (MoltArenaTypes.Bounty memory bounty);

    function getBounties(
        uint256 startId,
        uint256 limit
    ) external view returns (MoltArenaTypes.Bounty[] memory bounties);

    function getBountyTiming(
        uint256 bountyId
    ) external view returns (MoltArenaTypes.BountyTiming memory timing);

    function getSubmissionIds(
        uint256 bountyId
    ) external view returns (uint256[] memory submissionIds);

    function getEligibleSubmissionIds(
        uint256 bountyId
    ) external view returns (uint256[] memory submissionIds);

    function getWinnerSubmissionIds(
        uint256 bountyId
    ) external view returns (uint256[] memory winnerIds);

    function getRankedWinners(
        uint256 bountyId
    ) external view returns (MoltArenaTypes.RankedWinner[] memory winners);

    function availableVoteCredits(
        address account,
        uint256 bountyId
    ) external view returns (uint256);

    function lockedVoteCredits(
        address account,
        uint256 bountyId
    ) external view returns (uint256);

    function nextRequiredAction(
        address account,
        uint256 bountyId
    ) external view returns (string memory);

}
