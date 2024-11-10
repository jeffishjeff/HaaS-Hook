// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/// @title HookMiner - a library for mining hook addresses
/// @dev This library is intended for `forge test` environments. There may be gotchas when using salts in `forge script` or `forge create`
library HookMiner {
    /// @notice Find a salt that produces a hook address with the desired `flags`
    /// @param deployer The address that will deploy the hook. In `forge test`, this will be the test contract `address(this)` or the pranking address
    ///                 In `forge script`, this should be `0x4e59b44847b379578588920cA78FbF26c0B4956C` (CREATE2 Deployer Proxy)
    /// @param flags The desired flags for the hook address
    /// @param initCodeHash The keccak hash of the initCode of the contract to be deployed
    /// @return hookAddress salt and corresponding address that was found. The salt can be used in `new Hook{salt: salt}(<constructor arguments>)`
    function find(address deployer, uint160 flags, bytes32 initCodeHash)
        external
        view
        returns (address hookAddress, bytes32 salt)
    {
        bool valid;
        while (true) {
            bytes memory toHash = abi.encodePacked(bytes1(0xFF), deployer, salt, initCodeHash);
            hookAddress = address(uint160(uint256(keccak256(toHash))));

            assembly {
                valid := eq(and(hookAddress, flags), flags)
            }
            if (valid) {
                break;
            }

            salt = bytes32(gasleft());
        }
    }
}
