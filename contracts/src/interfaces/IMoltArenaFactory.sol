// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { MoltArenaTypes } from "../libraries/MoltArenaTypes.sol";
import { IMoltArenaVoteToken } from "./IMoltArenaVoteToken.sol";

interface IMoltArenaFactory {

    event BountyCreated(
        uint256 indexed bountyId,
        address indexed bounty,
        address indexed creator,
        string metadataURI,
        bytes32 settlementScopeHash,
        address settlementVerifier,
        uint96 rewardAmount,
        uint96 maxVoteCreditsPerVoter,
        uint16 winnerCount,
        uint40 submissionDeadline,
        uint40 commitDeadline,
        uint40 revealDeadline
    );

    event ImplementationUpdated(address indexed previousImplementation, address indexed newImplementation);

    error BountyNotFound(uint256 bountyId);
    error InvalidImplementation(address implementation);

    function rewardToken() external view returns (IERC20);

    function voteToken() external view returns (IMoltArenaVoteToken);

    function implementation() external view returns (address);

    function bountyCount() external view returns (uint256);

    function isBounty(
        address bounty
    ) external view returns (bool);

    function createBounty(
        MoltArenaTypes.CreateBountyParams calldata params
    ) external returns (uint256 bountyId, address bounty);

    function setImplementation(
        address newImplementation
    ) external;

    function getBountyAddress(
        uint256 bountyId
    ) external view returns (address bounty);

    function getBountyAddresses(
        uint256 startId,
        uint256 limit
    ) external view returns (address[] memory bounties);

}
