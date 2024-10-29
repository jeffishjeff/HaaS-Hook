> [!CAUTION]
> Not for production use!\
> This repo has not been thoroughly tested and audited, and there is also a known griefing attack vector that will cause any hook call to revert.

## Introduction

Uniswap v4 introduces an innovative new feature called hooks, where external smart contract functions can be invoked at various points during a pool's core logic flow such as before/after modifying liquidity or before/after swap.

To enable this, a pool in Uniswap v4 must specify this external smart contract address at its creation time, which becomes a part of the pool key (which derives pool ID). This permenant, one-to-one relationship guarantees exact interactions at bytecode level and it is up to the user to choose the pool with desired hooks logic. However, this architecture also leads to a number of practical challenges:

- For developers: developers may create new innovations with hooks but lack the resources or know-how to attract sufficient liquidity and volume, particularly for tokens pairs with strong existing incumbents, for them to be successful.

- For incentivizers: parties (e.g. token issurers, event organizers, etc.) may wish to temporarily incentivize liquidity and/or volume according to their business objectives. But existing pools/hooks may not provide such functionality (particularly hard for incentivizing liquidity) and it's not practical to deploy new ones for such purpose.

- For users: users are forced to choose between interacting with pools with deeper liquidity vs. pools with desired hooks logic.

**HaaS (Hooks as a Service) Hook** is an attempt to address these problems by decoupling pools from hooks logic, allowing multiple, ad hoc, and user specified hooks to execute on each pool action.

## HaaS Hook

At a high level, HaaS Hook is made up of a Provider Hooks, multiple Subscriber Hooks, and multiple User Specified Hooks. Provider Hooks functions as a dispatcher that forwards action hook calls to respective lists of Subscriber Hooks, as well as any User Specified Hooks provided by the caller.

#### Provider Hooks

The Provider Hooks implements `IProviderHooks` which in term inheirts `IHooks`. It is specified at a pool's creation time like the normal Uniswap v4 workflow, and has `Hooks.ALL_HOOK_MASK` flag turned on. Which means it implements all 10 action hooks and is permited to return all 4 deltas.

The `IProviderHooks` interface allows Subsriber Hooks to subscribe/unsubscribe themselves to action hooks on the Provider Hooks, either globally or for individual pools. They must commit a gas rebate (in basis points) for each subscription, which specifies how much the amount of gas (relative to actual usage) they are willing to pay. Subscriber Hooks must also maintain a gas retainer in the Provider Hooks where gas rebates are deducted from.

During a action hook call, Provider Hooks forwards call to both global and pool specific Subscriber Hooks that have subscribed to said action, in descending order of gas rebate committed, then User Specified Hooks in `hookData` are also called in the order specified. A Subscriber Hooks is skipped and unsubscribed if its gas retainer falls below a `minGasRetainer` threshold, and the whole process is short circuited if `gasleft` falls below a `minGasLeft` threshold.

Address bit checking logic in Uniswap v4 is omitted when Provider Hooks forwards calls, meaning that Subscriber Hooks and User Specified Hooks can be deployed at any address and still receive calls from subscribed actions. However, reture values are still checked to ensure success. For delta returning actions, the Provider Hooks returns the summation of that from all Subscriber Hooks and User Specified Hooks.

#### Subscriber Hooks

Subscriber Hooks are just regular `IHooks`. The only difference is that they will receive forwarded action hook calls from the Provider Hooks without checking their deployed address. That is, they can execute logics and return deltas even if respective flags in their deployed address says otherwise.

The same Subscriber Hooks will execute twice if it is subscribed to both the global as well as the pool specific list.

Anyone can `deposit` to the Subscriber Hooks' gas retainer, but only it can `withdraw` from it.

#### User Specified Hooks

User can specified additional hooks for execution by providering an `IHooks[]` value in `hookData`. User Specified Hooks are executed after Subscriber Hooks, if there is still enough gas left.

Currently the Provider Hooks does not check for duplication in User Specified Hooks.

## Constraints

- There is no gurantee of execution for any Subscriber Hooks or User Specified Hooks, depending on `gasleft` and gas rebate committed
- Subscriber Hooks and User Specified Hooks can make re-entry calls to the pool, but to prevent inifite loops, only action hook calls from the original sender are forwarded.
- Re-entry calls to `removeLiquidity` and `swap` are not allowed in `beforeSwap`
- Re-entry calls to `addLiquidity` is not allowed in `beforeDonate`
- `beforeSwap` cannot change the LP fee
- Positive deltas returned from Subscriber Hooks and User Specified Hooks are ignored (e.g. Subscriber Hooks and User Specified Hooks can give but not take tokens)
