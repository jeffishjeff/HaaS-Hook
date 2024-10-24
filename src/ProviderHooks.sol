// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {ParseBytes} from "v4-core/libraries/ParseBytes.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IProviderHooks} from "./interfaces/IProviderHooks.sol";
import {SafePoolId} from "./libraries/SafePoolId.sol";
import {Subscriber} from "./libraries/Subscriber.sol";

/// @notice ProviderHooks contract
contract ProviderHooks is IProviderHooks {
    using ParseBytes for bytes;
    using SafeCast for int256;
    using SafePoolId for PoolKey;
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;
    using Subscriber for mapping(IHooks => Subscriber.State);

    error NotPoolManager();
    error NotOriginalSender();
    error InvalidGasRebate();
    error InvalidDepositAmount();
    error InvalidWithdrawalAmount();
    error InvalidProviderHooksAddress();
    error GasTransferFailed();
    error CannotAddLiquidityInBeforeDonate();
    error CannotRemoveLiquidityInBeforeSwap();
    error CannotSwapInBeforeSwap();

    bool private isBeforeDonate; // TODO: convert to transient
    bool private isBeforeSwap; // TODO: convert to transient
    address private originalSender; // TODO: convert to transient, or would not work

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

    modifier onlyPoolManagerAndOriginalSender(address sender) {
        if (originalSender == address(0)) {
            originalSender = sender;
        }
        require(msg.sender == address(poolManager), NotPoolManager());
        require(sender == originalSender, NotOriginalSender());

        _;
    }

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

    /// @inheritdoc IHooks
    function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96)
        external
        onlyPoolManagerAndOriginalSender(sender)
        returns (bytes4)
    {
        bytes memory callData = abi.encodeCall(this.beforeInitialize, (sender, key, sqrtPriceX96));
        _callSubscribersAndRebateGas(key, IHooks.beforeInitialize.selector, callData, sender);

        return IHooks.beforeInitialize.selector;
    }

    /// @inheritdoc IHooks
    function afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick)
        external
        onlyPoolManagerAndOriginalSender(sender)
        returns (bytes4)
    {
        bytes memory callData = abi.encodeCall(this.afterInitialize, (sender, key, sqrtPriceX96, tick));
        _callSubscribersAndRebateGas(key, IHooks.afterInitialize.selector, callData, sender);

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

        bytes memory callData = abi.encodeCall(this.beforeAddLiquidity, (sender, key, params, hookData));
        _callSubscribersAndRebateGas(key, IHooks.beforeAddLiquidity.selector, callData, sender);

        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external onlyPoolManagerAndOriginalSender(sender) returns (bytes4, BalanceDelta) {
        BalanceDelta totalDelta;
        bytes memory callData =
            abi.encodeCall(this.afterAddLiquidity, (sender, key, params, delta, feesAccrued, hookData));
        bytes[] memory results = _callSubscribersAndRebateGas(key, IHooks.afterAddLiquidity.selector, callData, sender);

        for (uint256 i = 0; i < results.length; i++) {
            BalanceDelta _delta = BalanceDelta.wrap(results[i].parseReturnDelta());

            if (_delta.amount0() <= 0 && _delta.amount1() <= 0) {
                totalDelta = totalDelta + _delta;
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

        bytes memory callData = abi.encodeCall(this.beforeRemoveLiquidity, (sender, key, params, hookData));
        _callSubscribersAndRebateGas(key, IHooks.beforeRemoveLiquidity.selector, callData, sender);

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
        bytes memory callData =
            abi.encodeCall(this.afterRemoveLiquidity, (sender, key, params, delta, feesAccrued, hookData));
        bytes[] memory results =
            _callSubscribersAndRebateGas(key, IHooks.afterRemoveLiquidity.selector, callData, sender);

        for (uint256 i = 0; i < results.length; i++) {
            BalanceDelta _delta = BalanceDelta.wrap(results[i].parseReturnDelta());

            if (_delta.amount0() <= 0 && _delta.amount1() <= 0) {
                totalDelta = totalDelta + _delta;
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

        // using BalanceDelta instead of BeforeSwapDelta for + operator
        BalanceDelta totalDelta;
        bytes memory callData = abi.encodeCall(this.beforeSwap, (sender, key, params, hookData));
        bytes[] memory results = _callSubscribersAndRebateGas(key, IHooks.beforeSwap.selector, callData, sender);

        for (uint256 i = 0; i < results.length; i++) {
            BalanceDelta delta = BalanceDelta.wrap(results[i].parseReturnDelta());

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
        bytes memory callData = abi.encodeCall(this.afterSwap, (sender, key, params, delta, hookData));
        bytes[] memory results = _callSubscribersAndRebateGas(key, IHooks.afterSwap.selector, callData, sender);

        for (uint256 i = 0; i < results.length; i++) {
            int128 _delta = results[i].parseReturnDelta().toInt128();

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

        bytes memory callData = abi.encodeCall(this.beforeDonate, (sender, key, amount0, amount1, hookData));
        _callSubscribersAndRebateGas(key, IHooks.beforeDonate.selector, callData, sender);

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
        bytes memory callData = abi.encodeCall(this.afterDonate, (sender, key, amount0, amount1, hookData));
        _callSubscribersAndRebateGas(key, IHooks.afterDonate.selector, callData, sender);

        return IHooks.afterDonate.selector;
    }

    /// @inheritdoc IProviderHooks
    function gasRebateOf(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (uint32) {
        return subscribers[key.safeToId()][hook][subscriber].gasRebateBps;
    }

    /// @inheritdoc IProviderHooks
    function isSubscribed(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (bool) {
        return subscribers[key.safeToId()][hook][subscriber].gasRebateBps > 0;
    }

    function _subscribe(PoolKey calldata key, bytes4 hook, uint32 gasRebateBps) private {
        // Ensure that the gas rebate is at least 100%
        require(gasRebateBps >= BASIS_POINT_DENOMINATOR, InvalidGasRebate());

        PoolId poolId = key.safeToId();
        subscribers[poolId][hook].updateGasRebate(IHooks(msg.sender), gasRebateBps);

        emit Subscription(poolId, hook, IHooks(msg.sender), gasRebateBps);
    }

    function _unsubscribe(PoolKey calldata key, bytes4 hook) private {
        PoolId poolId = key.safeToId();
        subscribers[poolId][hook].updateGasRebate(IHooks(msg.sender), 0);

        emit Unsubscription(poolId, hook, IHooks(msg.sender));
    }

    function _gasTransfer(address recipient, uint256 amount) private {
        (bool success,) = recipient.call{value: amount}("");
        require(success, GasTransferFailed());
    }

    function _callSubscriber(IHooks subscriber, bytes memory data) private returns (bool, bytes memory) {
        (bool success, bytes memory result) = address(subscriber).call(data);
        // succeeds if call succeeds, result is at least 32 bytes long and return the correct selector
        success = success && result.length >= 32 && result.parseSelector() == data.parseSelector();

        return (success, result);
    }

    function _callSubscribersAndRebateGas(PoolKey calldata key, bytes4 hook, bytes memory data, address recipient)
        private
        returns (bytes[] memory)
    {
        uint256 index = 0;
        bytes[] memory results = new bytes[](1024); // TODO: hard coded value for now, needs improvement

        uint256 totalGasRebate = 0;
        mapping(IHooks => Subscriber.State) storage globalSubscribers = subscribers[SafePoolId.POOL_ID_ZERO][hook];
        IHooks globalCurrent = globalSubscribers[Subscriber.SUBSCRIBER_ZERO].next;

        if (hook == IHooks.beforeInitialize.selector || hook == IHooks.afterInitialize.selector) {
            // iterate through global subscribers only for initialization hooks
            while (gasleft() > minGasLeft && globalCurrent != Subscriber.SUBSCRIBER_ZERO) {
                if (retainerOf[globalCurrent] >= minRetainer) {
                    uint256 gasBefore = gasleft();
                    (bool success, bytes memory result) = _callSubscriber(globalCurrent, data);

                    if (success) {
                        results[index++] = result;
                    }

                    uint256 gasRebate = (gasBefore - gasleft()) * globalSubscribers[globalCurrent].gasRebateBps
                        / BASIS_POINT_DENOMINATOR;
                    gasRebate = gasRebate > retainerOf[globalCurrent] ? retainerOf[globalCurrent] : gasRebate;
                    retainerOf[globalCurrent] -= gasRebate;
                    totalGasRebate += gasRebate;
                } else {
                    globalSubscribers.updateGasRebate(globalCurrent, 0);
                }

                globalCurrent = globalSubscribers[globalCurrent].next;
            }
        } else {
            mapping(IHooks => Subscriber.State) storage poolSubscribers = subscribers[key.safeToId()][hook];
            IHooks poolCurrent = poolSubscribers[Subscriber.SUBSCRIBER_ZERO].next;

            // iterate through both global and pool subscribers for other hooks
            while (
                gasleft() > minGasLeft && globalCurrent != Subscriber.SUBSCRIBER_ZERO
                    && poolCurrent != Subscriber.SUBSCRIBER_ZERO
            ) {
                (bool isGlobal, IHooks current) = globalSubscribers[globalCurrent].gasRebateBps
                    >= poolSubscribers[poolCurrent].gasRebateBps ? (true, globalCurrent) : (false, poolCurrent);

                if (retainerOf[current] >= minRetainer) {
                    uint256 gasBefore = gasleft();
                    (bool success, bytes memory result) = _callSubscriber(current, data);

                    if (success) {
                        results[index++] = result;
                    }

                    uint256 gasRebate = (gasBefore - gasleft())
                        * (isGlobal ? globalSubscribers[current].gasRebateBps : poolSubscribers[current].gasRebateBps)
                        / BASIS_POINT_DENOMINATOR;
                    gasRebate = gasRebate > retainerOf[current] ? retainerOf[current] : gasRebate;
                    retainerOf[current] -= gasRebate;
                    totalGasRebate += gasRebate;
                } else {
                    if (isGlobal) {
                        globalSubscribers.updateGasRebate(globalCurrent, 0);
                    } else {
                        poolSubscribers.updateGasRebate(poolCurrent, 0);
                    }
                }

                if (isGlobal) {
                    globalCurrent = globalSubscribers[globalCurrent].next;
                } else {
                    poolCurrent = poolSubscribers[poolCurrent].next;
                }
            }
        }

        if (totalGasRebate > 0) {
            _gasTransfer(recipient, totalGasRebate);
        }

        return results;
    }
}
