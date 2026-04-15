// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console2 } from "forge-std/console2.sol";

import { MoltArenaLens } from "../../src/MoltArenaLens.sol";
import { IMoltArenaFactory } from "../../src/interfaces/IMoltArenaFactory.sol";

contract DeployLensXLayerScript is Script {

    using stdJson for string;

    string internal constant MAINNET_DEPLOYMENT_FILE = "/deployments/xlayer-mainnet.json";

    error MissingFactoryAddress();
    error MissingFactoryCode(address factory);

    function run() external returns (MoltArenaLens lens) {
        string memory deploymentJson = vm.readFile(string.concat(vm.projectRoot(), MAINNET_DEPLOYMENT_FILE));
        address factoryAddress = deploymentJson.readAddress(".arenaFactory.address");

        if (factoryAddress == address(0)) revert MissingFactoryAddress();
        if (factoryAddress.code.length == 0) revert MissingFactoryCode(factoryAddress);

        vm.startBroadcast();
        lens = new MoltArenaLens(IMoltArenaFactory(factoryAddress));
        vm.stopBroadcast();

        console2.log("Deployer:", tx.origin);
        console2.log("Arena factory:", factoryAddress);
        console2.log("MoltArenaLens:", address(lens));
        console2.log("Deployment source:", string.concat(vm.projectRoot(), MAINNET_DEPLOYMENT_FILE));
    }

}
