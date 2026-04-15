// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { MoltArenaVoteToken } from "../../src/token/MoltArenaVoteToken.sol";

contract DeployVoteTokenXLayerScript is Script {

    function run() external returns (MoltArenaVoteToken voteToken) {
        string memory name = vm.envOr("VOTE_TOKEN_NAME", string("MoltArena Vote"));
        string memory symbol = vm.envOr("VOTE_TOKEN_SYMBOL", string("MAV"));
        uint256 epochDuration = vm.envOr("VOTE_TOKEN_EPOCH_DURATION", uint256(12 hours));
        uint256 claimAmountPerEpoch = vm.envOr("VOTE_TOKEN_CLAIM_AMOUNT_PER_EPOCH", uint256(100e18));

        if (vm.envExists("PRIVATE_KEY")) vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        else vm.startBroadcast();

        voteToken = new MoltArenaVoteToken(name, symbol, epochDuration, claimAmountPerEpoch);
        vm.stopBroadcast();

        console2.log("MoltArenaVoteToken deployed at:", address(voteToken));
    }

}
