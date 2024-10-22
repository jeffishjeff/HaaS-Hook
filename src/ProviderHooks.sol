// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IProviderHooks} from "./interfaces/IProviderHooks.sol";
import {Subscriber} from "./libraries/Subscriber.sol";

contract ProviderHooks is IProviderHooks {
    using Subscriber for mapping(IHooks => Subscriber.State);

    error NotPoolManager();
    error InvalidProviderHooksAddress();
    error InvalidGasRebate();
    error GasTransferFailed();

    uint256 private constant BASIS_POINT_DENOMINATOR = 10_000;
    mapping(PoolId => mapping(bytes4 => mapping(IHooks => Subscriber.State))) private subscribers;

    IPoolManager public immutable poolManager;
    uint256 public immutable minGasLeft;
    uint256 public immutable minRetainer;
    mapping(IHooks => uint256) public retainerOf;

    modifier onlyPoolManager() {
        require(msg.sender == address(poolManager), NotPoolManager());
        _;
    }

    constructor(IPoolManager _poolManager, uint256 _minGasLeft, uint256 _minRetainer) {
        require(uint160(address(this)) & Hooks.ALL_HOOK_MASK == Hooks.ALL_HOOK_MASK, InvalidProviderHooksAddress());

        poolManager = _poolManager;
        minGasLeft = _minGasLeft;
        minRetainer = _minRetainer;
    }

    function subscribe(PoolKey calldata key, bytes4 hook, uint32 gasRebateBps) external {
        _subscribe(key, hook, gasRebateBps);
    }

    function subscribe(PoolKey calldata key, bytes4[] calldata hooks, uint32[] calldata gasRebatesBps) external {
        for (uint256 i = 0; i < hooks.length; i++) {
            _subscribe(key, hooks[i], gasRebatesBps[i]);
        }
    }

    function unsubscribe(PoolKey calldata key, bytes4 hook) external {
        _unsubscribe(key, hook);
    }

    function unsubscribe(PoolKey calldata key, bytes4[] calldata hooks) external {
        for (uint256 i = 0; i < hooks.length; i++) {
            _unsubscribe(key, hooks[i]);
        }
    }

    function deposit(IHooks subscriber) external payable {
        if (msg.value == 0) return;

        retainerOf[subscriber] += msg.value;

        emit Deposit(subscriber, msg.sender, msg.value);
    }

    function withdraw(uint256 amount, address recipient) external {
        if (amount == 0) amount = retainerOf[IHooks(msg.sender)];
        if (amount == 0) return;

        retainerOf[IHooks(msg.sender)] -= amount;
        _gasTransfer(recipient, amount);

        emit Withdrawal(IHooks(msg.sender), recipient, amount);
    }

    function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96)
        external
        onlyPoolManager
        returns (bytes4)
    {
        // TODO: implement
    }
    function afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick)
        external
        onlyPoolManager
        returns (bytes4)
    {
        // TODO: implement
    }
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4) {
        // TODO: implement
    }
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4, BalanceDelta) {
        // TODO: implement
    }
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4) {
        // TODO: implement
    }
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4, BalanceDelta) {
        // TODO: implement
    }
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
        // TODO: implement
    }
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4, int128) {
        // TODO: implement
    }
    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4) {
        // TODO: implement
    }
    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4) {
        // TODO: implement
    }

    function isSubscribed(PoolKey calldata key, bytes4 hook, IHooks subscriber) external view returns (bool) {
        return subscribers[key.toId()][hook][subscriber].gasRebateBps > 0;
    }

    function _subscribe(PoolKey calldata key, bytes4 hook, uint32 gasRebateBps) private {
        require(gasRebateBps >= BASIS_POINT_DENOMINATOR, InvalidGasRebate());

        subscribers[key.toId()][hook].updateGasRebate(IHooks(msg.sender), gasRebateBps);

        emit Subscription(key.toId(), hook, IHooks(msg.sender), gasRebateBps);
    }

    function _unsubscribe(PoolKey calldata key, bytes4 hook) private {
        subscribers[key.toId()][hook].updateGasRebate(IHooks(msg.sender), 0);

        emit Unsubscription(key.toId(), hook, IHooks(msg.sender));
    }

    function _gasTransfer(address recipient, uint256 amount) private {
        (bool success,) = recipient.call{value: amount}("");
        require(success, GasTransferFailed());
    }
}
