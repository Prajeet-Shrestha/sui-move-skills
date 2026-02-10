# Object Model

> Source: [Move Book Ch 6.3–6.5](https://move-book.com/object/object-model)

## What Is an Object?

Every Sui object has these properties:

| Property | Description |
|----------|-------------|
| **Type** | The struct type — defines structure and behavior |
| **UID** | Unique identifier, immutable after creation |
| **Owner** | Controls who can modify/transfer the object |
| **Version** | Increments on each mutation (acts as nonce) |
| **Digest** | Hash of object data — verifies integrity |

An object is any struct with the `key` ability whose first field is `id: UID`:

```move
public struct MyObject has key {
    id: UID,         // required first field
    data: u64,
}
```

## Four Ownership Types

### 1. Single Owner (Account-Owned)

The most common type. Only the owning account can use the object in transactions.

```move
// Transfer to the transaction sender
transfer::transfer(obj, ctx.sender());
```

**Properties:**
- Only the owner can pass it as input to transactions
- Enables **fast path** execution (no consensus needed)
- Ideal for: player-owned assets, personal inventory, capabilities

### 2. Shared

Anyone on the network can read and modify. Requires consensus.

```move
// Make the object shared — irreversible
transfer::share_object(obj);
```

**Properties:**
- Any account can access in transactions
- Requires **consensus** (slower, more expensive)
- Cannot be "unshared" once shared
- Ideal for: game state, registries, marketplaces, escrows

### 3. Immutable (Frozen)

Permanently read-only. Cannot be modified or transferred.

```move
// Freeze the object — irreversible
transfer::freeze_object(obj);
```

**Properties:**
- Anyone can read, nobody can modify
- Enables fast path (no contention)
- Ideal for: published configs, reference data, package metadata

### 4. Object-Owned

One object owns another. The child is accessed through the parent.

```move
// Transfer obj2 to be owned by obj1
transfer::transfer(obj2, object::id(&obj1).to_address());
```

**Properties:**
- Child is only accessible via the parent object
- Enables hierarchical composition (hero → inventory → items)
- Use `Receiving<T>` to accept objects sent to your object

## Fast Path vs Consensus

| Ownership | Execution Path | Speed | Cost |
|-----------|---------------|-------|------|
| Single owner | Fast path | ~400ms | Lowest |
| Immutable | Fast path | ~400ms | Lowest |
| Shared | Consensus | ~2-3s | Higher |
| Object-owned | Fast path | ~400ms | Lowest |

**Engine design implication:** Prefer owned objects where possible. Use shared objects only when multiple accounts genuinely need to modify the same state in the same epoch.

## Anti-Patterns

- **Don't share everything** — shared objects need consensus, making them slower and more expensive
- **Don't expose UID mutably** unless necessary — mutable `&mut UID` access allows anyone to add/remove dynamic fields
- **Don't store secrets** — object contents are always readable off-chain regardless of ownership
