> [!CAUTION]
> Not for production use!\
> This repo has not been thoroughly tested or audited, and it contains a known griefing attack vector that can cause hook call to revert.

## Introduction

Uniswap v4 introduces an innovative new feature called hooks, which allows external smart contract functions to be invoked at various points in a pool's core logic flow, such as before or after modifying liquidity, or before or after swap.

To enable this functionality, a Uniswap v4 pool must specify an external smart contract address at creation, which then becomes a part of the pool key (which derives pool ID). This permenant, one-to-one relationship ensures exact interactions at the bytecode level, and it is up to the users to select pools based on their desired hooks logic. However, this setup poses several challenges:

- For Developers: while developers can create new innovations with hooks, they may struggle to attract liquidity and volume to make them successful, especially for token pairs with strong incumbent pools.

- For Incentivizers: parties (e.g., token issurers, event organizers, etc.) may want to incentivize liquidity and/or volume according to their business needs. Existing pools/hooks may not provide this functionality, particularly for incentivizing liquidity, and it is impractical to deploy new pools solely for this purpose.

- For Users: users are forced to choose between pools with deeper liquidity and whos with specific hooks logic.

**Hooks as a Service (HaaS) Hook** aims to solve these issues by decoupling pools from hooks logic, enabling multiple, ad hoc, and user specified hooks for each pool action.

## HaaS Hook

The HaaS Hook refers to a system that consists of a Provider Hooks, multiple Subscriber Hooks, and multiple User Specified Hooks. The Provider Hooks acts as a dispatcher, forwarding each hook call to the respective list of Subscriber Hooks and any User Specified Hooks provided by the caller.

#### Provider Hooks

The Provider Hooks implements the `IProviderHooks` interface, which inheirts `IHooks`. It is set at the pool's creation, following the standard Uniswap v4 workflow, with the `Hooks.ALL_HOOK_MASK` flag enabled. Which indicates that it supports all 10 action hooks and can return all 4 deltas.

The `IProviderHooks` interface allows Subsriber Hooks to subscribe to or unsubscribe from specific hooks on the Provider Hooks, either globally or for individual pools. Each subscription requires a committed gas rebate (in basis points) relative to actual gas usage. Subscriber Hooks must also maintain a gas retainer within the Provider Hook, from which gas rebates are deducted.

During a hook call, the Provider Hooks sequentially forwards the call to global and pool specific Subscriber Hooks, ordered by their committed gas rebate, followed by User Specified Hooks in the `hookData` parameter. A Subscriber Hook is skipped and unsubscribed if its gas retainer falls below the `minGasRetainer` threshold, and the whole process stops if `gasleft` falls below the `minGasLeft` threshold.

The Provider Hook bypasses the address bit-checking logic in Uniswap V4, allowing Subscriber and User Specified Hooks to be deployed at any address. However, return values are checked to ensure successful execution. For delta-returning actions, the Provider Hook aggregates the deltas returned from all Subscriber and User Specified Hooks.

#### Subscriber Hooks

Subscriber Hooks are just regular `IHooks` but receive forwarded hook calls from the Provider Hook without any address validation. That is, they can execute logic and return deltas even if their deployed address does not reflect the respective flags.

A Subscriber Hook will execute twice if subscribed to both the global and pool specific lists.

Anyone can deposit to a Subscriber Hook’s gas retainer, but only the hook itself can withdraw from it.

#### User Specified Hooks

User can specify additional hooks by providering an `IHooks[]` array in the `hookData`. These User Specified Hooks are executed after Subscriber Hooks, provided that sufficient gas remains.

Currently, the Provider Hooks does not check for duplicate User Specified Hooks.

## Constraints

- Execution Guarantees: There is no guarantee of execution for any Subscriber or User Specified Hook, as this depends on `gasleft` and the committed gas rebate value.
- Re-Entrancy: Subscriber and User Specified Hooks can make re-entry calls to the pool. However, to prevent infinite loops, only hook calls from the original sender are forwarded.
- Re-entry calls to `removeLiquidity` and `swap` are disallowed in `beforeSwap`.
- Re-entry calls to `addLiquidity` is disallowed in `beforeDonate`.
- LP Fee Modification: `beforeSwap` cannot change the LP fee.
- Delta Constraints: Positive deltas returned from Subscriber or User Specified Hooks are ignored, meaning they can give but not take tokens. Also, each Subscriber or User Specified Hooks must settle its non-zero delta accounts.
