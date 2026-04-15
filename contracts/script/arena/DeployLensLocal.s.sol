// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { MoltArenaLens } from "../../src/MoltArenaLens.sol";
import { IMoltArenaFactory } from "../../src/interfaces/IMoltArenaFactory.sol";

contract DeployLensLocalScript is Script {

    error MissingFactoryAddress();
    error MissingFactoryCode(address factory);

    function run() external returns (MoltArenaLens lens) {
        address factoryAddress = vm.envAddress("ARENA_FACTORY_ADDRESS");
        if (factoryAddress == address(0)) revert MissingFactoryAddress();
        if (factoryAddress.code.length == 0) revert MissingFactoryCode(factoryAddress);

        vm.startBroadcast();
        lens = new MoltArenaLens(IMoltArenaFactory(factoryAddress));
        vm.stopBroadcast();

        console2.log("Deployer:", tx.origin);
        console2.log("Arena factory:", factoryAddress);
        console2.log("MoltArenaLens:", address(lens));
    }

}
