// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console2 } from "forge-std/console2.sol";

import { MoltArenaFactory } from "../../src/MoltArenaFactory.sol";
import { MoltArenaVoteToken } from "../../src/token/MoltArenaVoteToken.sol";

contract DeployArenaFactoryXLayerScript is Script {

    using stdJson for string;

    string internal constant MAINNET_DEPLOYMENT_FILE = "/deployments/xlayer-mainnet.json";

    error MissingWOKBCode(address wokb);
    error MissingVoteTokenAddress();
    error MissingVoteTokenCode(address voteToken);
    error MissingBountyImplementationAddress();
    error MissingBountyImplementationCode(address implementation);
    error DeploymentRewardTokenMismatch(address expected, address actual);

    function run() external returns (MoltArenaVoteToken voteToken, MoltArenaFactory factory) {
        string memory deploymentJson = vm.readFile(string.concat(vm.projectRoot(), MAINNET_DEPLOYMENT_FILE));
        address rewardTokenAddress = deploymentJson.readAddress(".rewardToken.address");
        address voteTokenAddress = deploymentJson.readAddress(".voteToken.address");
        address bountyImplementation = deploymentJson.readAddress(".bountyImplementation.address");

        if (voteTokenAddress == address(0)) revert MissingVoteTokenAddress();
        if (bountyImplementation == address(0)) revert MissingBountyImplementationAddress();
        if (voteTokenAddress.code.length == 0) revert MissingVoteTokenCode(voteTokenAddress);
        if (bountyImplementation.code.length == 0) revert MissingBountyImplementationCode(bountyImplementation);

        vm.startBroadcast();

        voteToken = MoltArenaVoteToken(voteTokenAddress);
        factory = new MoltArenaFactory(bountyImplementation, voteToken);

        voteToken.grantRole(voteToken.CONSUMER_MANAGER_ROLE(), address(factory));

        vm.stopBroadcast();

        if (address(factory.rewardToken()) != rewardTokenAddress) {
            revert DeploymentRewardTokenMismatch(address(factory.rewardToken()), rewardTokenAddress);
        }
        if (address(factory.rewardToken()).code.length == 0) revert MissingWOKBCode(address(factory.rewardToken()));

        console2.log("Deployer:", tx.origin);
        console2.log("Reward token:", address(factory.rewardToken()));
        console2.log("Vote token:", address(voteToken));
        console2.log("Bounty implementation:", bountyImplementation);
        console2.log("Arena factory:", address(factory));
        console2.log("Deployment source:", string.concat(vm.projectRoot(), MAINNET_DEPLOYMENT_FILE));
    }

}
