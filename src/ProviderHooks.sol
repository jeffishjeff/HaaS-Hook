// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {ParseBytes} from "v4-core/libraries/ParseBytes.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IProviderHooks} from "./interfaces/IProviderHooks.sol";
import {PoolKeyLibrary} from "./libraries/PoolKeyLibrary.sol";
import {Subscriber} from "./libraries/Subscriber.sol";

/// @notice ProviderHooks contract
contract ProviderHooks is IProviderHooks {
    using ParseBytes for bytes;
    using PoolKeyLibrary for PoolKey;
    using Subscriber for mapping(IHooks => Subscriber.State);

    error InvalidGasRebate();
    error InvalidDepositAmount();
    error InvalidWithdrawalAmount();
    error InvalidProviderHooksAddress();
    error GasTransferFailed();

    uint256 private constant BASIS_POINT_DENOMINATOR = 10_000;
    // Linked list of subscribers, sorted by gas rebate descending
    mapping(PoolId => mapping(bytes4 => mapping(IHooks => Subscriber.State))) private subscribers;

    /// @inheritdoc IProviderHooks
    IPoolManager public immutable poolManager;
    /// @inheritdoc IProviderHooks
    uint256 public immutable minGasLeft;
    /// @inheritdoc IProviderHooks
    uint256 public immutable minRetainer;
    /// @inheritdoc IProviderHooks
    mapping(IHooks => uint256) public retainerOf;

    constructor(IPoolManager _poolManager, uint256 _minGasLeft, uint256 _minRetainer) {
        // Ensure that the contract address has all hook permissions
        require(uint160(address(this)) & Hooks.ALL_HOOK_MASK == Hooks.ALL_HOOK_MASK, InvalidProviderHooksAddress());

        poolManager = _poolManager;
        minGasLeft = _minGasLeft;
        minRetainer = _minRetainer;
    }

    /// @inheritdoc IProviderHooks
    function subscribe(PoolKey calldata key, bytes4 hook, uint32 gasRebateBps) external {
        _subscribe(key, hook, gasRebateBps);
    }

    /// @inheritdoc IProviderHooks
    function subscribe(PoolKey calldata key, bytes4[] calldata hooks, uint32[] calldata gasRebatesBps) external {
        for (uint256 i = 0; i < hooks.length; i++) {
            _subscribe(key, hooks[i], gasRebatesBps[i]);
        }
    }

    /// @inheritdoc IProviderHooks
    function unsubscribe(PoolKey calldata key, bytes4 hook) external {
        _unsubscribe(key, hook);
    }

    /// @inheritdoc IProviderHooks
    function unsubscribe(PoolKey calldata key, bytes4[] calldata hooks) external {
        for (uint256 i = 0; i < hooks.length; i++) {
            _unsubscribe(key, hooks[i]);
        }
    }

    /// @inheritdoc IProviderHooks
    function deposit(IHooks subscriber) external payable {
        // Ensure that the deposit amount is positive
        require(msg.value > 0, InvalidDepositAmount());

        retainerOf[subscriber] += msg.value;

        emit Deposit(subscriber, msg.sender, msg.value);
    }

    /// @inheritdoc IProviderHooks
    function withdraw(uint256 amount, address recipient) external {
        if (amount == 0) amount = retainerOf[IHooks(msg.sender)];
        // Ensure that the withdrawal amount is positive
        require(amount > 0, InvalidWithdrawalAmount());

        retainerOf[IHooks(msg.sender)] -= amount;
        _gasTransfer(recipient, amount);

        emit Withdrawal(IHooks(msg.sender), recipient, amount);
    }

    /// @inheritdoc IProviderHooks
    function gasRebateOf(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (uint32) {
        return subscribers[key.toIdOrZero()][hook][subscriber].gasRebateBps;
    }

    /// @inheritdoc IProviderHooks
    function isSubscribed(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (bool) {
        return subscribers[key.toIdOrZero()][hook][subscriber].gasRebateBps > 0;
    }

    function _subscribe(PoolKey calldata key, bytes4 hook, uint32 gasRebateBps) private {
        // Ensure that the gas rebate is at least 100%
        require(gasRebateBps >= BASIS_POINT_DENOMINATOR, InvalidGasRebate());

        PoolId poolId = key.toIdOrZero();
        subscribers[poolId][hook].updateGasRebate(IHooks(msg.sender), gasRebateBps);

        emit Subscription(poolId, hook, IHooks(msg.sender), gasRebateBps);
    }

    function _unsubscribe(PoolKey calldata key, bytes4 hook) private {
        PoolId poolId = key.toIdOrZero();
        subscribers[poolId][hook].updateGasRebate(IHooks(msg.sender), 0);

        emit Unsubscription(poolId, hook, IHooks(msg.sender));
    }

    function _gasTransfer(address recipient, uint256 amount) private {
        (bool success,) = recipient.call{value: amount}("");
        require(success, GasTransferFailed());
    }
}
