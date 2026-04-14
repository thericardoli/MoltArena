// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import { IMoltArenaVoteToken } from "../interfaces/IMoltArenaVoteToken.sol";

contract MoltArenaVoteToken is ERC20, AccessControl, IMoltArenaVoteToken {

    bytes32 public constant CONSUMER_ROLE = keccak256("CONSUMER_ROLE");
    bytes32 public constant CONSUMER_MANAGER_ROLE = keccak256("CONSUMER_MANAGER_ROLE");

    uint256 public immutable override epochDuration;
    uint256 public immutable override claimAmountPerEpoch;
    uint256 public immutable override claimStartTimestamp;

    mapping(address => uint256) public override lastClaimedEpoch;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 epochDuration_,
        uint256 claimAmountPerEpoch_
    ) ERC20(name_, symbol_) {
        if (epochDuration_ == 0) revert InvalidEpochDuration();
        if (claimAmountPerEpoch_ == 0) revert InvalidClaimAmount();

        epochDuration = epochDuration_;
        claimAmountPerEpoch = claimAmountPerEpoch_;
        claimStartTimestamp = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONSUMER_MANAGER_ROLE, msg.sender);
    }

    function currentEpoch() public view override returns (uint256) {
        return ((block.timestamp - claimStartTimestamp) / epochDuration) + 1;
    }

    function canClaim(
        address account
    ) public view override returns (bool) {
        uint256 epoch = currentEpoch();
        return epoch > 0 && lastClaimedEpoch[account] < epoch;
    }

    function claim() external override {
        uint256 epoch = currentEpoch();
        if (epoch == 0 || lastClaimedEpoch[msg.sender] >= epoch) revert AlreadyClaimedForEpoch(msg.sender, epoch);

        lastClaimedEpoch[msg.sender] = epoch;
        _mint(msg.sender, claimAmountPerEpoch);
        emit Claimed(msg.sender, epoch, claimAmountPerEpoch);
    }

    function grantConsumer(
        address consumer
    ) external override onlyRole(CONSUMER_MANAGER_ROLE) {
        _grantRole(CONSUMER_ROLE, consumer);
    }

    function revokeConsumer(
        address consumer
    ) external override onlyRole(CONSUMER_MANAGER_ROLE) {
        _revokeRole(CONSUMER_ROLE, consumer);
    }

    function consume(
        address from,
        uint256 amount
    ) external override onlyRole(CONSUMER_ROLE) {
        _burn(from, amount);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        if (from != address(0) && to != address(0)) revert TransfersDisabled();

        super._update(from, to, value);
    }

    }
