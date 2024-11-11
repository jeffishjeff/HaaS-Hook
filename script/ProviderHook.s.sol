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
    uint160 HOOK_PERMISSIONS = Hooks.ALL_HOOK_MASK;

    struct NetworkConfig {
        address poolManager;
        uint256 minGasLeft;
        uint256 minGasRetainer;
        uint256 maxSubscriberCalls;
        address expectedAddress;
        bytes32 salt;
    }

    NetworkConfig UnichainSepolia =
        NetworkConfig(address(0xC81462Fec8B23319F288047f8A03A57682a35C1A), 200, 500, 50, address(0), bytes32(0x0));

    NetworkConfig Sepolia =
        NetworkConfig(address(0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A), 200, 500, 50, address(0), bytes32(0x0));

    function getConfigByChainId() private view returns (NetworkConfig memory) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        if (chainId == 1301) return UnichainSepolia;
        if (chainId == 11155111) return Sepolia;

        revert("no config found.");
    }

    function run() external {
        NetworkConfig memory cfg = getConfigByChainId();

        bytes memory constructorArgs =
            abi.encode(cfg.poolManager, cfg.minGasLeft, cfg.minGasRetainer, cfg.maxSubscriberCalls);
        bytes memory initCode = abi.encodePacked(type(ProviderHook).creationCode, constructorArgs);

        if (cfg.expectedAddress == address(0)) {
            bytes32 initCodeHash = keccak256(initCode);
            (cfg.expectedAddress, cfg.salt) = HookMiner.find(CREATE2_DEPLOYER, HOOK_PERMISSIONS, initCodeHash);
        }

        console.log("expected hook address: ", cfg.expectedAddress);
        console.log("salt: ", vm.toString(cfg.salt));

        vm.startBroadcast();
        address deployedAddress;
        bytes32 salt = cfg.salt;
        assembly {
            deployedAddress := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }
        vm.stopBroadcast();
        console.log("deployed hook address: ", deployedAddress);

        require(deployedAddress == cfg.expectedAddress, "DeployScript: hook address mismatch");
    }
}
