> [!CAUTION]
> Not for production use!\
> This repo has not been thoroughly tested and audited, and there is also a known griefing attack vector that will cause any hook call to revert.

## Introduction

Uniswap v4 introduces an innovative new feature called hooks, where external smart contract functions can be invoked at various points during a pool's core logic flow such as before/after modifying liquidity or before/after swap.

To enable this, a pool in Uniswap v4 must specify this external smart contract address at its creation time, which becomes a part of the pool key (which derives pool ID). This permenant, one-to-one relationship guarantees exact interactions at bytecode level and it is up to the user to choose the pool with desired hooks logic. However, this architecture also leads to a number of practical challenges:

- For developers: developers may create new innovations with hooks but lack the resources or know-how to attract sufficient liquidity and volume, particularly for tokens pairs with strong existing incumbents, for them to be successful.

- For incentivizers: parties (e.g. token issurers, event organizers, etc.) may wish to temporarily incentivize liquidity and/or volume according to their business objectives. But existing pools/hooks may not provide such functionality (particularly hard for incentivizing liquidity) and it's not practical to deploy new ones for such purpose.

- For users: users are forced to choose between interacting with pools with deeper liquidity vs. pools with desired hooks logic.

**HaaS (Hooks as a Service) Hook** solves these problems by decoupling pools from hooks logic, allowing multiple, ad hoc, and user specified hooks to execute on each pool action.

2 Host Hooks

- Multiple commensal and transient hooks
- Ignore address encoding/constraints
- Commensals before transients
- Error handling

3 Commensal Hooks

- Attach and detach
- Bidding for execution
- Gas deposit and refill
- Global or pool specific

4 Transient Hooks

- User specified during execution
- HookData encoding

Cannot swap or remove liquidity in before swap
Cannot add liquidity in before donate
Before swap cannot change lp fee
Cannot return positive balance delta
No guarantee of execution or order of execution
Action by other than original sender is not propagated
