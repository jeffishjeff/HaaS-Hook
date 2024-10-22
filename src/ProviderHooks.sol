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
    error NotPoolManager();
    error InvalidProviderHooksAddress();

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
        // TODO: implement
    }
    function subscribe(PoolKey calldata key, bytes4[] calldata hooks, uint32[] calldata gasRebatesBps) external {
        // TODO: implement
    }
    function unsubscribe(PoolKey calldata key, bytes4 hook) external {
        // TODO: implement
    }
    function unsubscribe(PoolKey calldata key, bytes4[] calldata hooks) external {
        // TODO: implement
    }
    function deposit(IHooks subscriber) external payable {
        // TODO: implement
    }
    function withdraw(uint256 amount, address recipient) external {
        // TODO: implement
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
}
