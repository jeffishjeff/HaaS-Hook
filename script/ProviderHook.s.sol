// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {ProviderHook} from "../src/ProviderHook.sol";
import {HookMiner} from "./HookMiner.sol";

contract Deploy is Script {
    // forge create2 deployer
    address CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function run() external {
        address poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");
        uint256 minGasLeft = vm.envUint("MIN_GAS_LEFT");
        uint256 minGasRetainer = vm.envUint("MIN_GAS_RETAINER");
        uint256 maxSubscriberCalls = vm.envUint("MAX_SUBSCRIBER_CALLS");

        bytes memory constructorArgs = abi.encode(poolManager, minGasLeft, minGasRetainer, maxSubscriberCalls);
        bytes memory initCode = abi.encodePacked(type(ProviderHook).creationCode, constructorArgs);
        bytes32 initCodeHash = keccak256(initCode);

        uint160 flags = Hooks.ALL_HOOK_MASK;
        (address expectedAddress, bytes32 salt) = HookMiner.find(CREATE2_DEPLOYER, flags, initCodeHash);
        console.log("expected hook address: ", expectedAddress);

        vm.startBroadcast();
        address deployedAddress;
        assembly {
            deployedAddress := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }
        vm.stopBroadcast();
        console.log("deployed hook address: ", deployedAddress);

        require(deployedAddress == expectedAddress, "DeployScript: hook address mismatch");
    }
}
