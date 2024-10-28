// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {ParseBytes} from "v4-core/libraries/ParseBytes.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IProviderHooks} from "./interfaces/IProviderHooks.sol";
import {GlobalOrPoolId} from "./libraries/GlobalOrPoolId.sol";
import {Subscriber} from "./libraries/Subscriber.sol";

/// @notice ProviderHooks contract
contract ProviderHooks is IProviderHooks {
    using SafeCast for int256;
    using ParseBytes for bytes;
    using GlobalOrPoolId for PoolKey;
    using Subscriber for mapping(IHooks => Subscriber.State);

    /// @notice Thrown when message sender is not the pool manager
    error NotPoolManager();
    /// @notice Thrown when deploying to an invalid provider hooks address
    error InvalidProviderHooksAddress();
    /// @notice Thrown when a gas transfer fails
    error GasTransferFailed();
    /// @notice Thrown when trying to add liquidity in beforeDonate
    error CannotAddLiquidityInBeforeDonate();
    /// @notice Thrown when trying to remove liquidity in beforeSwap
    error CannotRemoveLiquidityInBeforeSwap();
    /// @notice Thrown when trying to swap in beforeSwap
    error CannotSwapInBeforeSwap();

    uint256 private constant BASIS_POINT_DENOMINATOR = 10_000;
    address private originalSender; // TODO: convert to transient, currently broken
    bool private isBeforeDonate; // TODO: convert to transient
    bool private isBeforeSwap; // TODO: convert to transient
    mapping(PoolId => mapping(bytes4 => mapping(IHooks => Subscriber.State))) private subscribers;

    /// @inheritdoc IProviderHooks
    IPoolManager public immutable poolManager;
    /// @inheritdoc IProviderHooks
    uint256 public immutable minGasLeft;
    /// @inheritdoc IProviderHooks
    uint256 public immutable minGasRetainer;
    /// @inheritdoc IProviderHooks
    uint256 public immutable maxSubscriberCalls;
    /// @inheritdoc IProviderHooks
    mapping(IHooks => uint256) public gasRetainerOf;

    // can only be called by the pool manager with the original sender
    modifier onlyPoolManagerAndOriginalSender(address sender) {
        require(msg.sender == address(poolManager), NotPoolManager());

        if (originalSender == address(0)) {
            originalSender = sender;
        }

        if (sender == originalSender) {
            _;
        }
    }

    constructor(IPoolManager _poolManager, uint256 _minGasLeft, uint256 _minGasRetainer, uint256 _maxSubscriberCalls) {
        // ensures that the contract address has all the hook permissions
        require(uint160(address(this)) & Hooks.ALL_HOOK_MASK == Hooks.ALL_HOOK_MASK, InvalidProviderHooksAddress());

        poolManager = _poolManager;
        minGasLeft = _minGasLeft;
        minGasRetainer = _minGasRetainer;
        maxSubscriberCalls = _maxSubscriberCalls;
    }

    // ***********************************
    // ***** IProviderHooks Funtions *****
    // ***********************************

    /// @inheritdoc IProviderHooks
    function subscribe(PoolKey calldata key, bytes4 hook, uint32 gasRebateBps) external {
        // ensures that the gas rebate is at least 10_000 basis points
        require(gasRebateBps >= BASIS_POINT_DENOMINATOR, InvalidGasRebate());

        PoolId poolId = key.toGlobalOrPoolId();
        subscribers[poolId][hook].updateGasRebate(IHooks(msg.sender), gasRebateBps);

        emit Subscription(poolId, hook, IHooks(msg.sender), gasRebateBps);
    }

    /// @inheritdoc IProviderHooks
    function unsubscribe(PoolKey calldata key, bytes4 hook) external {
        _unsubscribe(key.toGlobalOrPoolId(), hook, IHooks(msg.sender));
    }

    /// @inheritdoc IProviderHooks
    function deposit(IHooks subscriber) external payable {
        // ensures that the deposit amount is greater than 0
        require(msg.value > 0, InvalidGasRetainerTransferAmount());

        gasRetainerOf[subscriber] += msg.value;

        emit Deposit(subscriber, msg.sender, msg.value);
    }

    /// @inheritdoc IProviderHooks
    function withdraw(uint256 amount, address recipient) external {
        if (amount == 0) amount = gasRetainerOf[IHooks(msg.sender)];
        // ensures that the withdrawal amount is greater than 0
        require(amount > 0, InvalidGasRetainerTransferAmount());

        gasRetainerOf[IHooks(msg.sender)] -= amount;
        _gasTransfer(recipient, amount);

        emit Withdrawal(IHooks(msg.sender), recipient, amount);
    }

    /// @inheritdoc IProviderHooks
    function isSubscribed(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (bool) {
        return subscribers[key.toGlobalOrPoolId()][hook][subscriber].gasRebateBps > 0;
    }

    /// @inheritdoc IProviderHooks
    function gasRebateOf(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (uint32) {
        return subscribers[key.toGlobalOrPoolId()][hook][subscriber].gasRebateBps;
    }

    // ***************************
    // ***** IHooks Funtions *****
    // ***************************

    /// @inheritdoc IHooks
    function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96)
        external
        onlyPoolManagerAndOriginalSender(sender)
        returns (bytes4)
    {
        bytes memory callData = abi.encodeCall(this.beforeInitialize, (sender, key, sqrtPriceX96));
        _callSubscribersAndRebateGas(key, IHooks.beforeInitialize.selector, callData, new IHooks[](0), sender);

        return IHooks.beforeInitialize.selector;
    }

    /// @inheritdoc IHooks
    function afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick)
        external
        onlyPoolManagerAndOriginalSender(sender)
        returns (bytes4)
    {
        bytes memory callData = abi.encodeCall(this.afterInitialize, (sender, key, sqrtPriceX96, tick));
        _callSubscribersAndRebateGas(key, IHooks.afterInitialize.selector, callData, new IHooks[](0), sender);

        return IHooks.afterInitialize.selector;
    }

    /// @inheritdoc IHooks
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external onlyPoolManagerAndOriginalSender(sender) returns (bytes4) {
        require(!isBeforeDonate, CannotAddLiquidityInBeforeDonate());

        IHooks[] memory userHooks = abi.decode(hookData, (IHooks[]));
        bytes memory callData = abi.encodeCall(this.beforeAddLiquidity, (sender, key, params, ""));
        _callSubscribersAndRebateGas(key, IHooks.beforeAddLiquidity.selector, callData, userHooks, sender);

        return IHooks.beforeAddLiquidity.selector;
    }

    /// @inheritdoc IHooks
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external onlyPoolManagerAndOriginalSender(sender) returns (bytes4, BalanceDelta) {
        BalanceDelta totalDelta;
        IHooks[] memory userHooks = abi.decode(hookData, (IHooks[]));
        bytes memory callData = abi.encodeCall(this.afterAddLiquidity, (sender, key, params, delta, feesAccrued, ""));
        bytes[] memory results =
            _callSubscribersAndRebateGas(key, IHooks.afterAddLiquidity.selector, callData, userHooks, sender);

        // balance delta returned is sum of that from all subscribers
        for (uint256 i = 0; i < results.length; i++) {
            delta = BalanceDelta.wrap(results[i].parseReturnDelta());

            // ignore subscribers that try to take/mint tokens
            if (delta.amount0() <= 0 && delta.amount1() <= 0) {
                totalDelta = totalDelta + delta;
            }
        }

        return (IHooks.afterAddLiquidity.selector, totalDelta);
    }

    /// @inheritdoc IHooks
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external onlyPoolManagerAndOriginalSender(sender) returns (bytes4) {
        require(!isBeforeSwap, CannotRemoveLiquidityInBeforeSwap());

        IHooks[] memory userHooks = abi.decode(hookData, (IHooks[]));
        bytes memory callData = abi.encodeCall(this.beforeRemoveLiquidity, (sender, key, params, ""));
        _callSubscribersAndRebateGas(key, IHooks.beforeRemoveLiquidity.selector, callData, userHooks, sender);

        return IHooks.beforeRemoveLiquidity.selector;
    }

    /// @inheritdoc IHooks
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external onlyPoolManagerAndOriginalSender(sender) returns (bytes4, BalanceDelta) {
        BalanceDelta totalDelta;
        IHooks[] memory userHooks = abi.decode(hookData, (IHooks[]));
        bytes memory callData = abi.encodeCall(this.afterRemoveLiquidity, (sender, key, params, delta, feesAccrued, ""));
        bytes[] memory results =
            _callSubscribersAndRebateGas(key, IHooks.afterRemoveLiquidity.selector, callData, userHooks, sender);

        // balance delta returned is sum of that from all subscribers
        for (uint256 i = 0; i < results.length; i++) {
            delta = BalanceDelta.wrap(results[i].parseReturnDelta());

            // ignore subscribers that try to take/mint tokens
            if (delta.amount0() <= 0 && delta.amount1() <= 0) {
                totalDelta = totalDelta + delta;
            }
        }

        return (IHooks.afterRemoveLiquidity.selector, totalDelta);
    }

    /// @inheritdoc IHooks
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external onlyPoolManagerAndOriginalSender(sender) returns (bytes4, BeforeSwapDelta, uint24) {
        require(!isBeforeSwap, CannotSwapInBeforeSwap());

        isBeforeSwap = true;

        // using BalanceDelta instead of BeforeSwapDelta for the + operator
        BalanceDelta totalDelta;
        IHooks[] memory userHooks = abi.decode(hookData, (IHooks[]));
        bytes memory callData = abi.encodeCall(this.beforeSwap, (sender, key, params, ""));
        bytes[] memory results =
            _callSubscribersAndRebateGas(key, IHooks.beforeSwap.selector, callData, userHooks, sender);

        // before swap delta (currently represented as BalanceDelta) returned is sum of that from all subscribers
        for (uint256 i = 0; i < results.length; i++) {
            BalanceDelta delta = BalanceDelta.wrap(results[i].parseReturnDelta());

            // ignore subscribers that try to take/mint tokens
            if (delta.amount0() <= 0 && delta.amount1() <= 0) {
                totalDelta = totalDelta + delta;
            }
        }

        isBeforeSwap = false;

        // never change LP fee
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(BalanceDelta.unwrap(totalDelta)), 0);
    }

    /// @inheritdoc IHooks
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external onlyPoolManagerAndOriginalSender(sender) returns (bytes4, int128) {
        int128 totalDelta;
        IHooks[] memory userHooks = abi.decode(hookData, (IHooks[]));
        bytes memory callData = abi.encodeCall(this.afterSwap, (sender, key, params, delta, ""));
        bytes[] memory results =
            _callSubscribersAndRebateGas(key, IHooks.afterSwap.selector, callData, userHooks, sender);

        // delta returned is sum of that from all subscribers
        for (uint256 i = 0; i < results.length; i++) {
            int128 _delta = results[i].parseReturnDelta().toInt128();

            // ignore subscribers that try to take/mint tokens
            if (_delta < 0) {
                totalDelta += _delta;
            }
        }

        return (IHooks.afterSwap.selector, totalDelta);
    }

    /// @inheritdoc IHooks
    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external onlyPoolManagerAndOriginalSender(sender) returns (bytes4) {
        isBeforeDonate = true;

        IHooks[] memory userHooks = abi.decode(hookData, (IHooks[]));
        bytes memory callData = abi.encodeCall(this.beforeDonate, (sender, key, amount0, amount1, ""));
        _callSubscribersAndRebateGas(key, IHooks.beforeDonate.selector, callData, userHooks, sender);

        isBeforeDonate = false;

        return IHooks.beforeDonate.selector;
    }

    /// @inheritdoc IHooks
    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external onlyPoolManagerAndOriginalSender(sender) returns (bytes4) {
        IHooks[] memory userHooks = abi.decode(hookData, (IHooks[]));
        bytes memory callData = abi.encodeCall(this.afterDonate, (sender, key, amount0, amount1, ""));
        _callSubscribersAndRebateGas(key, IHooks.afterDonate.selector, callData, userHooks, sender);

        return IHooks.afterDonate.selector;
    }

    // ***************************
    // ***** Helper Funtions *****
    // ***************************

    function _unsubscribe(PoolId poolId, bytes4 hook, IHooks subscriber) private {
        subscribers[poolId][hook].updateGasRebate(subscriber, 0);

        emit Unsubscription(poolId, hook, subscriber);
    }

    function _gasTransfer(address recipient, uint256 amount) private {
        (bool success,) = recipient.call{value: amount}("");
        require(success, GasTransferFailed());
    }

    function _callSubscribersAndRebateGas(
        PoolKey calldata key,
        bytes4 hook,
        bytes memory data,
        IHooks[] memory userHooks,
        address gasRecipient
    ) private returns (bytes[] memory) {
        uint256 resultIndex = 0;
        uint256 userHookIndex = 0;
        bytes[] memory results = new bytes[](maxSubscriberCalls + userHooks.length);

        uint256 totalGasRebate = 0;
        mapping(IHooks => Subscriber.State) storage globalSubscribers = subscribers[GlobalOrPoolId.GLOBAL_ID][hook];
        IHooks globalSubscriber = globalSubscribers[Subscriber.SUBSCRIBER_ORIGIN].next;
        mapping(IHooks => Subscriber.State) storage poolSubscribers = subscribers[key.toGlobalOrPoolId()][hook];
        // for beforeInitialize() and afterInitialize(), this will already point to the subscriber origin
        IHooks poolSubscriber = poolSubscribers[Subscriber.SUBSCRIBER_ORIGIN].next;

        // call global and pool specific subscribers as long as there is subscriber left, enough gas left, and max call limit is not reached
        while (
            (globalSubscriber != Subscriber.SUBSCRIBER_ORIGIN || poolSubscriber != Subscriber.SUBSCRIBER_ORIGIN)
                && gasleft() > minGasLeft && resultIndex < maxSubscriberCalls
        ) {
            // get the next subscriber with the highest gas rebate, favoring pool subscribers in case of a tie
            (IHooks subscriber, uint32 gasRebateBps, bool isGlobal) = globalSubscribers[globalSubscriber].gasRebateBps
                > poolSubscribers[poolSubscriber].gasRebateBps
                ? (globalSubscriber, globalSubscribers[globalSubscriber].gasRebateBps, true)
                : (poolSubscriber, poolSubscribers[poolSubscriber].gasRebateBps, false);

            if (gasRetainerOf[subscriber] < minGasRetainer) {
                // unsubscribe the subscriber if the gas retainer is below the minimum
                _unsubscribe(isGlobal ? GlobalOrPoolId.GLOBAL_ID : key.toGlobalOrPoolId(), hook, subscriber);
            } else {
                uint256 gasBefore = gasleft();
                (bool success, bytes memory result) = address(subscriber).call(data);

                // ensure the call was successful and the result is valid
                if (success && result.length >= 32 && result.parseSelector() == data.parseSelector()) {
                    results[resultIndex] = result;
                }

                // calculate gas rebate and update gas retainer
                uint256 gasRebate = (gasBefore - gasleft()) * gasRebateBps / BASIS_POINT_DENOMINATOR;
                gasRebate = gasRebate > gasRetainerOf[subscriber] ? gasRetainerOf[subscriber] : gasRebate;
                gasRetainerOf[subscriber] -= gasRebate;
                totalGasRebate += gasRebate;
            }

            // advance index and subscriber
            resultIndex++;
            if (isGlobal) {
                globalSubscriber = globalSubscribers[globalSubscriber].next;
            } else {
                poolSubscriber = poolSubscribers[poolSubscriber].next;
            }
        }

        // call user specified hooks as long as there is gas left, user pays gas
        while (userHookIndex < userHooks.length && gasleft() > minGasLeft) {
            (bool success, bytes memory result) = address(userHooks[userHookIndex]).call(data);

            // ensure the call was successful and the result is valid
            if (success && result.length >= 32 && result.parseSelector() == data.parseSelector()) {
                results[resultIndex + userHookIndex++] = result;
            }
        }

        // transfer gas rebate to the gas recipient
        if (totalGasRebate > 0) {
            _gasTransfer(gasRecipient, totalGasRebate);
        }

        return results;
    }
}
