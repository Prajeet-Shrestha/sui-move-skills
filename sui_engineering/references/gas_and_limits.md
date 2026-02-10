# Gas & Protocol Limits

> Source: [Move Book — Building Against Limits](https://move-book.com/guides/building-against-limits)

## Protocol Limits

These limits are enforced by the network. Exceeding any of them causes the transaction to be **rejected or aborted**.

| Limit | Value | Scope |
|-------|-------|-------|
| **Transaction size** | 128 KB | Total payload + signature + metadata |
| **Object size** | 256 KB | Single object (BCS-serialized) |
| **Pure argument size** | 16 KB | Single argument passed from client |
| **Objects created** | 2,048 | Per transaction |
| **Dynamic fields created** | ~1,000 | Per transaction (key + value = 2 objects each) |
| **Dynamic fields accessed** | 1,000 | Per transaction (reads + writes) |
| **Events emitted** | 1,024 | Per transaction |

---

## Working Within Limits

### Transaction Size (128 KB)

The 128 KB limit covers the entire transaction. In practice, this rarely matters unless you're passing large vectors as arguments.

**Workaround**: Split batch operations across multiple transactions from the client.

### Object Size (256 KB)

A single object cannot exceed 256 KB when BCS-serialized.

```move
// ❌ PROBLEM: storing a growing vector in the object
public struct Leaderboard has key {
    id: UID,
    entries: vector<LeaderboardEntry>,  // grows unbounded → will hit 256KB
}

// ✅ SOLUTION: use Table (dynamic field-backed, no size limit)
public struct Leaderboard has key {
    id: UID,
    entries: Table<u64, LeaderboardEntry>,  // each entry is a separate dynamic field
}
```

**Rule of thumb**: If a collection can grow without bound, use `Table`/`Bag`/`LinkedTable` instead of `vector`/`VecMap`/`VecSet`.

### Pure Argument Size (16 KB)

A single argument from the client is limited to 16 KB. This is roughly ~500 addresses.

```move
// ❌ PROBLEM: can't pass more than ~500 addresses in one argument
public fun airdrop_to_all(recipients: vector<address>, ...) { ... }

// ✅ SOLUTION: join vectors dynamically
public fun airdrop_batch(
    existing: &mut vector<address>,
    batch: vector<address>,
) {
    existing.append(batch);
}
// Client sends multiple batches via PTB, then calls the actual airdrop
```

### Dynamic Fields per Transaction (1,000 created / 1,000 accessed)

Each dynamic field operation (add/borrow/remove) counts as an access. Creating a dynamic field counts against both the created and accessed limits.

```move
// ❌ PROBLEM: spawning 100 entities with 15 components each
// = 100 entities + 1,500 dynamic fields = over limit
public fun mass_spawn(count: u64, ...) { ... }

// ✅ SOLUTION: batch across transactions
// Client sends: spawn_batch(10), spawn_batch(10), ... in separate transactions
```

**Engine guidance**: A single entity with ~10 components costs ~10 dynamic field creates. You can safely create ~100 entities per transaction.

### Events per Transaction (1,024)

```move
// ❌ PROBLEM: emitting an event per item in a batch
public fun process_batch(items: vector<Item>, ...) {
    items.do_ref!(|item| {
        process(item);
        event::emit(ItemProcessed { ... }); // 1 event per item
    });
}

// ✅ SOLUTION: emit a summary event
public fun process_batch(items: vector<Item>, ...) {
    let count = items.length();
    items.do_ref!(|item| process(item));
    event::emit(BatchProcessed { count, ... }); // 1 event total
}
```

---

## Gas Optimization Tips

### 1. Minimize dynamic field accesses

```move
// ❌ EXPENSIVE: multiple borrows of the same field
let health = health::borrow(&entity);
let is_alive = health.current() > 0;
// ... later ...
let hp = health::borrow(&entity); // second df read!

// ✅ CHEAPER: borrow once, use the reference
let health = health::borrow(&entity);
let is_alive = health.current() > 0;
let hp = health.current(); // reuse same reference
```

### 2. Use `exists_` before conditional access

```move
// ❌ WASTEFUL: borrow + check vs just checking existence
let has = if (df::exists_(&uid, key)) {
    let component = df::borrow(&uid, key);
    component.some_field > 0
} else {
    false
};

// ✅ BETTER for simple existence: just check
let has = df::exists_(&uid, key);
```

### 3. Avoid unnecessary object creation

```move
// ❌ EXPENSIVE: creating a Coin just to convert to Balance
let coin = coin::mint(cap, amount, ctx);  // creates object
let balance = coin.into_balance();         // destroys object

// ✅ CHEAPER: mint directly as Balance
let balance = coin::mint_balance(cap, amount); // no object overhead
```

### 4. Use `Balance<T>` over `Coin<T>` inside structs

`Balance` has `store` only (no `key`), so it doesn't create a separate object. `Coin` has `key + store` and creates an object with a UID.

```move
// ❌ EXPENSIVE: storing Coin in a struct
public struct Treasury has key {
    id: UID,
    funds: Coin<SUI>,  // nested object overhead
}

// ✅ CHEAPER: use Balance
public struct Treasury has key {
    id: UID,
    funds: Balance<SUI>,  // just data, no object
}
```
