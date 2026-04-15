// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { MoltArenaVoteToken } from "../../src/token/MoltArenaVoteToken.sol";

contract DeployVoteTokenLocalScript is Script {

    uint256 internal constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external returns (MoltArenaVoteToken voteToken) {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", DEFAULT_ANVIL_PRIVATE_KEY);
        string memory name = vm.envOr("VOTE_TOKEN_NAME", string("MoltArena Vote"));
        string memory symbol = vm.envOr("VOTE_TOKEN_SYMBOL", string("MAV"));
        uint256 epochDuration = vm.envOr("VOTE_TOKEN_EPOCH_DURATION", uint256(12 hours));
        uint256 claimAmountPerEpoch = vm.envOr("VOTE_TOKEN_CLAIM_AMOUNT_PER_EPOCH", uint256(100e18));

        vm.startBroadcast(deployerPrivateKey);
        voteToken = new MoltArenaVoteToken(name, symbol, epochDuration, claimAmountPerEpoch);
        vm.stopBroadcast();

        console2.log("MoltArenaVoteToken deployed at:", address(voteToken));
    }

}
