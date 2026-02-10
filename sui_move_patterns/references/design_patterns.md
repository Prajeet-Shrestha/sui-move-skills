# Design Patterns

> Source: [Move Book Ch 8.4, 8.7, 8.11–8.12, 8.16](https://move-book.com/programmability/)

## Pattern: Capability

**Problem**: How to restrict certain operations to authorized users?

**Solution**: Use owned objects as authorization tokens. A function requires a reference to a capability object — only the owner can provide it.

```move
/// Created once in init(), transferred to deployer
public struct AdminCap has key, store { id: UID }

/// Only callable if you own an AdminCap
public fun set_config(_cap: &AdminCap, registry: &mut Registry, value: u64) {
    registry.value = value;
}

/// Create AdminCap at package publish
fun init(ctx: &mut TxContext) {
    transfer::transfer(
        AdminCap { id: object::new(ctx) },
        ctx.sender()
    );
}
```

**Conventions:**
- Name with `Cap` suffix: `AdminCap`, `MinterCap`, `OperatorCap`
- Created in `init()` — guarantees single instance at deploy
- Pass by reference (`&AdminCap`) for authorization checks
- Use `key, store` so the cap can be transferred to other accounts

**Engine use case**: Admin operations on registries, game pause/unpause, parameter tuning.

---

## Pattern: Witness

**Problem**: How to prove that a call originates from a specific module?

**Solution**: A module proves ownership of a type by constructing it. Only the defining module can create instances of its types.

```move
module game::my_token;

/// The witness — only this module can create it
public struct MY_TOKEN has drop {}

/// Uses the witness for one-time initialization
fun init(witness: MY_TOKEN, ctx: &mut TxContext) {
    // witness proves this is the my_token module
    let supply = balance::create_supply(witness);
    // ...
}
```

**Key properties:**
- A witness is typically a struct with `drop` (consumed immediately)
- The receiving function takes it by value
- Only the defining module can create the struct → proof of module identity

**Engine use case**: Creating typed supplies, registering component types, package identity verification.

---

## Pattern: One-Time Witness (OTW)

A special witness guaranteed to be created **exactly once**, in the module's `init` function.

**OTW rules** (enforced by Sui):
1. Named after the module in ALL CAPS (e.g., module `my_coin` → struct `MY_COIN`)
2. Has only the `drop` ability
3. Has no fields
4. Automatically passed as the first argument to `init`

```move
module game::my_coin;

/// OTW: matches module name, has only `drop`, no fields
public struct MY_COIN has drop {}

fun init(witness: MY_COIN, ctx: &mut TxContext) {
    // `witness` is guaranteed to exist only once
}
```

**Engine use case**: One-time initialization of coin types, unique registry creation.

---

## Pattern: Hot Potato

**Problem**: How to ensure a multi-step operation is completed within a single transaction?

**Solution**: Create a struct with **no abilities**. It cannot be stored, copied, or dropped — so it must be consumed by a specific function before the transaction ends.

```move
/// No abilities = must be consumed
public struct MoveRequest {
    entity_id: ID,
    from_x: u64,
    from_y: u64,
}

/// Start a move — returns a hot potato
public fun begin_move(entity: &Entity): MoveRequest {
    let pos = position::borrow(entity);
    MoveRequest {
        entity_id: object::id(entity),
        from_x: pos.x(),
        from_y: pos.y(),
    }
}

/// Complete the move — consumes the hot potato
public fun complete_move(
    entity: &mut Entity,
    request: MoveRequest,
    to_x: u64,
    to_y: u64,
) {
    let MoveRequest { entity_id, from_x, from_y } = request;
    // Validate and apply the move...
}
```

**Applications:**
- **Borrowing**: Take a value out, must return it (with a Promise)
- **Flash loans**: Borrow funds, must repay in the same tx
- **Multi-step workflows**: Force completion of state machine transitions
- **Variable-path execution**: Different paths to consume the potato

**Engine use case**: Enforcing that a game action sequence completes (e.g., declare attack → resolve attack → apply damage).

---

## Pattern: Wrapper Type

**Problem**: How to add behavior to a type you don't control?

**Solution**: Wrap it in a new struct that adds the desired abilities or constraints.

```move
/// Wraps any T to add a timestamp
public struct Timestamped<T: store> has key, store {
    id: UID,
    value: T,
    created_at: u64,
}
```

**Engine use case**: Adding metadata (timestamps, creators) to arbitrary component types.

## Summary: When to Use Each Pattern

| Pattern | Solves | Engine Layer |
|---------|--------|-------------|
| Capability | Authorization | Admin controls, game operator |
| Witness | Module identity proof | Type registration, coin creation |
| OTW | One-time initialization | Registry setup, package init |
| Hot Potato | Forced transaction completion | Multi-step game actions |
| Wrapper | Extending foreign types | Adding metadata to components |
