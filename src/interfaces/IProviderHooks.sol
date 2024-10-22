// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

interface IProviderHooks is IHooks {
    event Subscription(PoolId indexed poolId, bytes4 indexed hook, IHooks indexed subscriber, uint32 gasRebateBps);
    event Unsubscription(PoolId indexed poolId, bytes4 indexed hook, IHooks indexed subscriber);
    event Deposit(IHooks indexed subscriber, address indexed depositor, uint256 amount);
    event Withdrawal(IHooks indexed subscriber, address indexed recipient, uint256 amount);

    function subscribe(PoolKey calldata key, bytes4 hook, uint32 gasRebateBps) external;
    function subscribe(PoolKey calldata key, bytes4[] calldata hooks, uint32[] calldata gasRebatesBps) external;
    function unsubscribe(PoolKey calldata key, bytes4 hook) external;
    function unsubscribe(PoolKey calldata key, bytes4[] calldata hooks) external;
    function deposit(IHooks subscriber) external payable;
    function withdraw(uint256 amount, address recipient) external;

    function poolManager() external view returns (IPoolManager);
    function minGasLeft() external view returns (uint256);
    function minRetainer() external view returns (uint256);
    function retainerOf(IHooks subscriber) external view returns (uint256);
    function isSubscribed(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (bool);
}
