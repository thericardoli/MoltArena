// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IMoltArenaBounty } from "./interfaces/IMoltArenaBounty.sol";
import { IMoltArenaFactory } from "./interfaces/IMoltArenaFactory.sol";
import { IMoltArenaVoteToken } from "./interfaces/IMoltArenaVoteToken.sol";
import { MoltArenaTypes } from "./libraries/MoltArenaTypes.sol";

contract MoltArenaFactory is Ownable, IMoltArenaFactory {

    using SafeERC20 for IERC20;

    address public constant WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
    IERC20 public constant override rewardToken = IERC20(WOKB);
    IMoltArenaVoteToken public immutable override voteToken;

    address public override implementation;
    uint256 public override bountyCount;

    mapping(uint256 bountyId => address bounty) private _bountyAddresses;
    mapping(address bounty => bool registered) public override isBounty;

    constructor(
        address implementation_,
        IMoltArenaVoteToken voteToken_
    ) Ownable(msg.sender) {
        voteToken = voteToken_;
        _setImplementation(implementation_);
    }

    function createBounty(
        MoltArenaTypes.CreateBountyParams calldata params
    ) external override returns (uint256 bountyId, address bounty) {
        address creator = msg.sender;
        address settlementVerifier = params.settlementVerifier == address(0) ? creator : params.settlementVerifier;
        bounty = Clones.clone(implementation);
        bountyId = ++bountyCount;

        _bountyAddresses[bountyId] = bounty;
        isBounty[bounty] = true;

        IMoltArenaBounty(bounty).initialize(bountyId, creator, rewardToken, voteToken, address(this), params);
        voteToken.grantConsumer(bounty);
        rewardToken.safeTransferFrom(creator, bounty, params.rewardAmount);

        _emitBountyCreated(bountyId, bounty, creator, settlementVerifier, params);
    }

    function setImplementation(
        address newImplementation
    ) external override onlyOwner {
        _setImplementation(newImplementation);
    }

    function getBountyAddress(
        uint256 bountyId
    ) public view override returns (address bounty) {
        bounty = _bountyAddresses[bountyId];
        if (bounty == address(0)) revert BountyNotFound(bountyId);
    }

    function getBountyAddresses(
        uint256 startId,
        uint256 limit
    ) external view override returns (address[] memory bounties) {
        if (limit == 0 || startId == 0 || startId > bountyCount) return new address[](0);

        uint256 endExclusive = startId + limit;
        if (endExclusive > bountyCount + 1) endExclusive = bountyCount + 1;

        uint256 resultLength = endExclusive - startId;
        bounties = new address[](resultLength);

        for (uint256 i; i < resultLength; ++i) {
            bounties[i] = _bountyAddresses[startId + i];
        }
    }

    function _setImplementation(
        address newImplementation
    ) internal {
        if (newImplementation == address(0) || newImplementation.code.length == 0) {
            revert InvalidImplementation(newImplementation);
        }

        address previousImplementation = implementation;
        implementation = newImplementation;

        emit ImplementationUpdated(previousImplementation, newImplementation);
    }

    function _emitBountyCreated(
        uint256 bountyId_,
        address bounty,
        address creator,
        address settlementVerifier,
        MoltArenaTypes.CreateBountyParams calldata params
    ) internal {
        emit BountyCreated(
            bountyId_,
            bounty,
            creator,
            params.metadataURI,
            params.settlementScopeHash,
            settlementVerifier,
            params.rewardAmount,
            params.maxVoteCreditsPerVoter,
            params.winnerCount,
            params.submissionDeadline,
            params.commitDeadline,
            params.revealDeadline
        );
    }

}
