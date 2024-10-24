// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

/// @notice Interface for the ProviderHooks contract
interface IProviderHooks is IHooks {
    /// @notice Emitted when a subscriber subscribes to the hook of the pool (or globally if poolId is 0)
    /// @param poolId The ID of the pool the subscriber is subscribing to
    /// @param hook The hook the subscriber is subscribing to
    /// @param subscriber The subscriber that is subscribing
    /// @param gasRebateBps The gas rebate (relative to gas consumed) the subscriber is paying, in basis points
    event Subscription(PoolId indexed poolId, bytes4 indexed hook, IHooks indexed subscriber, uint32 gasRebateBps);

    /// @notice Emitted when a subscriber unsubscribes from the hook of the pool (or globally if poolId is 0)
    /// @param poolId The ID of the pool the subscriber is unsubscribing from
    /// @param hook The hook the subscriber is unsubscribing from
    /// @param subscriber The subscriber that is unsubscribing
    event Unsubscription(PoolId indexed poolId, bytes4 indexed hook, IHooks indexed subscriber);

    /// @notice Emitted when retainer is increased for a subscriber
    /// @param subscriber The subscriber whose retainer is increased
    /// @param depositor The depositor who paid for the deposit
    /// @param amount The amount of the deposit
    event Deposit(IHooks indexed subscriber, address indexed depositor, uint256 amount);

    /// @notice Emitted when the retainer is decreased for a subscriber
    /// @param subscriber The subscriber whose retainer is decreased
    /// @param recipient The recipient who received the withdrawal
    /// @param amount The amount of the withdrawal
    event Withdrawal(IHooks indexed subscriber, address indexed recipient, uint256 amount);

    /// @notice Subscribes message sender to the hook of the pool (or globally if poolKey is empty), offering gas rebate in basis points
    /// @param key The pool key of the pool the message sender is subscribing to
    /// @param hook The hook the message sender is subscribing to
    /// @param gasRebateBps The gas rebate (relative to gas consumed) the message sender is paying, in basis points
    function subscribe(PoolKey calldata key, bytes4 hook, uint32 gasRebateBps) external;

    /// @notice Subscribes message sender to the hooks of the pool (or globally if poolKey is empty), offering gas rebates in basis points
    /// @param key The pool key of the pool the message sender is subscribing to
    /// @param hooks The hooks the message sender is subscribing to
    /// @param gasRebatesBps The gas rebates (relative to gas consumed) the message sender is paying, in basis points
    function subscribe(PoolKey calldata key, bytes4[] calldata hooks, uint32[] calldata gasRebatesBps) external;

    /// @notice Unsubscribes message sender from the hook of the pool (or globally if poolKey is empty)
    /// @param key The pool key of the pool the message sender is unsubscribing from
    /// @param hook The hook the message sender is unsubscribing from
    function unsubscribe(PoolKey calldata key, bytes4 hook) external;

    /// @notice Unsubscribes message sender from the hooks of the pool (or globally if poolKey is empty)
    /// @param key The pool key of the pool the message sender is unsubscribing from
    /// @param hooks The hooks the message sender is unsubscribing from
    function unsubscribe(PoolKey calldata key, bytes4[] calldata hooks) external;

    /// @notice Deposits to a subscriber's retainer
    /// @param subscriber The subscriber whose retainer is increased
    function deposit(IHooks subscriber) external payable;

    /// @notice Withdraws from message sender's retainer
    /// @param amount The amount to withdraw
    /// @param recipient The recipient of the withdrawal
    function withdraw(uint256 amount, address recipient) external;

    /// @notice Gets the pool manager this provider hooks is associated with
    /// @return The pool manager
    function poolManager() external view returns (IPoolManager);

    /// @notice Gets the minimum gas left required for calling the next subscriber
    /// @return The minimum gas left
    function minGasLeft() external view returns (uint256);

    /// @notice Gets the minimum retainer required for a subscriber to be called
    /// @return The minimum retainer
    function minRetainer() external view returns (uint256);

    /// @notice Gets the retainer of the subscriber
    /// @param subscriber The subscriber being queried
    /// @return The retainer of the subscriber
    function retainerOf(IHooks subscriber) external view returns (uint256);

    /// @notice Gets the gas rebate of the subscriber for the hook of the pool
    /// @param key The pool key being queried
    /// @param hook The hook being queried
    /// @param subscriber The subscriber being queried
    /// @return The gas rebate of the subscriber
    function gasRebateOf(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (uint32);

    /// @notice Gets whether the subscriber is subscribed to the hook of the pool
    /// @param key The pool key being queried
    /// @param hook The hook being queried
    /// @param subscriber The subscriber being queried
    /// @return Whether the subscriber is subscribed
    function isSubscribed(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (bool);
}
