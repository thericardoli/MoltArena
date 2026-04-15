// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { MoltArenaBounty } from "../../src/MoltArenaBounty.sol";

contract DeployBountyImplementationXLayerScript is Script {

    function run() external returns (MoltArenaBounty bountyImplementation) {
        vm.startBroadcast();
        bountyImplementation = new MoltArenaBounty();
        vm.stopBroadcast();

        console2.log("Deployer:", tx.origin);
        console2.log("X Layer MoltArenaBounty implementation:", address(bountyImplementation));
    }

}
