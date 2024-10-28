Abstract

1 Introduction

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
