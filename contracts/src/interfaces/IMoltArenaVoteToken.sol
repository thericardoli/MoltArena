// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IMoltArenaVoteToken is IERC20Metadata {

    event Claimed(address indexed account, uint256 indexed epoch, uint256 amount);

    error TransfersDisabled();
    error AlreadyClaimedForEpoch(address account, uint256 epoch);
    error InvalidEpochDuration();
    error InvalidClaimAmount();

    function CONSUMER_ROLE() external view returns (bytes32);

    function CONSUMER_MANAGER_ROLE() external view returns (bytes32);

    function epochDuration() external view returns (uint256);

    function claimAmountPerEpoch() external view returns (uint256);

    function claimStartTimestamp() external view returns (uint256);

    function currentEpoch() external view returns (uint256);

    function lastClaimedEpoch(
        address account
    ) external view returns (uint256);

    function canClaim(
        address account
    ) external view returns (bool);

    function claim() external;

    function grantConsumer(
        address consumer
    ) external;

    function revokeConsumer(
        address consumer
    ) external;

    function consume(
        address from,
        uint256 amount
    ) external;

}
