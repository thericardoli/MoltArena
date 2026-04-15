// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console2 } from "forge-std/console2.sol";

import { MoltArenaBounty } from "../../src/MoltArenaBounty.sol";
import { MoltArenaFactory } from "../../src/MoltArenaFactory.sol";
import { MoltArenaVoteToken } from "../../src/token/MoltArenaVoteToken.sol";

contract DeployArenaFactoryLocalScript is Script {

    using stdJson for string;

    string internal constant MAINNET_DEPLOYMENT_FILE = "/deployments/xlayer-mainnet.json";

    error MissingWOKBCode(address wokb);
    error DeploymentRewardTokenMismatch(address expected, address actual);
    error MissingVoteTokenCode(address voteToken);

    function run()
        external
        returns (MoltArenaVoteToken voteToken, MoltArenaBounty bountyImplementation, MoltArenaFactory factory)
    {
        string memory deploymentJson = vm.readFile(string.concat(vm.projectRoot(), MAINNET_DEPLOYMENT_FILE));
        address rewardTokenAddress = deploymentJson.readAddress(".rewardToken.address");
        address voteTokenAddress = deploymentJson.readAddress(".voteToken.address");

        if (voteTokenAddress.code.length == 0) revert MissingVoteTokenCode(voteTokenAddress);

        vm.startBroadcast();

        voteToken = MoltArenaVoteToken(voteTokenAddress);
        bountyImplementation = new MoltArenaBounty();
        factory = new MoltArenaFactory(address(bountyImplementation), voteToken);

        voteToken.grantRole(voteToken.CONSUMER_MANAGER_ROLE(), address(factory));

        vm.stopBroadcast();

        if (address(factory.rewardToken()) != rewardTokenAddress) {
            revert DeploymentRewardTokenMismatch(address(factory.rewardToken()), rewardTokenAddress);
        }
        if (address(factory.rewardToken()).code.length == 0) revert MissingWOKBCode(address(factory.rewardToken()));

        console2.log("Deployer:", tx.origin);
        console2.log("Reward token:", address(factory.rewardToken()));
        console2.log("Vote token:", address(voteToken));
        console2.log("Bounty implementation:", address(bountyImplementation));
        console2.log("Arena factory:", address(factory));
        console2.log("Deployment source:", string.concat(vm.projectRoot(), MAINNET_DEPLOYMENT_FILE));
    }

}
