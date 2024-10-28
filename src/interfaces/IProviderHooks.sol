// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

/// @notice Interface for the ProviderHooks contract
interface IProviderHooks is IHooks {
    /// @notice Thrown when the gas rebate offered is less than 10_000 basis points
    error InvalidGasRebate();
    /// @notice Thrown when depositing or withdrawing 0 gas retainer
    error InvalidGasRetainerTransferAmount();

    /// @notice Emitted when a subscriber subscribes to a global or pool specific hook
    /// @param poolId The global or pool specific identifier
    /// @param hook The hook the subscriber is subscribing to
    /// @param subscriber The subscriber that is subscribing
    /// @param gasRebateBps The gas rebate the subscriber is offering, in basis points
    event Subscription(PoolId indexed poolId, bytes4 indexed hook, IHooks indexed subscriber, uint32 gasRebateBps);

    /// @notice Emitted when a subscriber unsubscribes from a global or pool specific hook
    /// @param poolId The global or pool specific identifier
    /// @param hook The hook the subscriber is unsubscribing from
    /// @param subscriber The subscriber that is unsubscribing
    event Unsubscription(PoolId indexed poolId, bytes4 indexed hook, IHooks indexed subscriber);

    /// @notice Emitted when the gas retainer of a subscriber is deposited to
    /// @param subscriber The subscriber whose gas retainer is deposited to
    /// @param depositor The depositor of the gas retainer
    /// @param amount The amount of the deposit
    event Deposit(IHooks indexed subscriber, address indexed depositor, uint256 amount);

    /// @notice Emitted when the gas retainer of a subscriber is withdrawn from
    /// @param subscriber The subscriber whose gas retainer is withdrawn from
    /// @param recipient The recipient of the withdrawal
    /// @param amount The amount of the withdrawal
    event Withdrawal(IHooks indexed subscriber, address indexed recipient, uint256 amount);

    /// @notice Subscribes the message sender to a global or pool specific hook, in position according to gas rebate offered
    /// @param key The pool key to derive global or pool specific identifier
    /// @param hook The hook to subscribe to
    /// @param gasRebateBps The gas rebate offered, in basis points
    function subscribe(PoolKey calldata key, bytes4 hook, uint32 gasRebateBps) external;

    /// @notice Unsubscribes the message sender from a global or pool specific hook
    /// @param key The pool key to derive global or pool specific identifier
    /// @param hook The hook to unsubscribe from
    function unsubscribe(PoolKey calldata key, bytes4 hook) external;

    /// @notice Deposits to the gas retainer of a subscriber
    /// @param subscriber The subscriber whose gas retainer is deposited to
    function deposit(IHooks subscriber) external payable;

    /// @notice Withdraws from the gas retainer of a subscriber
    /// @param amount The amount to withdraw, 0 to withdraw all
    /// @param recipient The recipient of the withdrawal
    function withdraw(uint256 amount, address recipient) external;

    /// @notice Gets the pool manager of this provider hooks
    /// @return The pool manager
    function poolManager() external view returns (IPoolManager);

    /// @notice Gets the minimum gas left required for calling the next subscriber
    /// @return The minimum gas left
    function minGasLeft() external view returns (uint256);

    /// @notice Gets the minimum gas retainer required for a subscriber to be called
    /// @return The minimum gas retainer
    function minGasRetainer() external view returns (uint256);

    /// @notice Gets the maximum number of subscriber to be called per hook
    /// @return The maximum number of subscriber calls per hook
    function maxSubscriberCalls() external view returns (uint256);

    /// @notice Gets the gas retainer of a subscriber
    /// @param subscriber The subscriber being queried
    /// @return The gas retainer of the subscriber
    function gasRetainerOf(IHooks subscriber) external view returns (uint256);

    /// @notice Gets whether a subscriber is subscribed to a global or pool specific hook
    /// @param key The pool key to derive global or pool specific identifier
    /// @param hook The hook being queried
    /// @param subscriber The subscriber being queried
    /// @return Whether the subscriber is subscribed
    function isSubscribed(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (bool);

    /// @notice Gets the gas rebate of a subscriber for a global or pool specific hook
    /// @param key The pool key to derive global or pool specific identifier
    /// @param hook The hook being queried
    /// @param subscriber The subscriber being queried
    /// @return The gas rebate of the subscriber, in basis points
    function gasRebateOf(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (uint32);
}
