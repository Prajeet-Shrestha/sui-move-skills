# Sui Move Skills — Cheatsheet

> Distilled from [sui-move-skills](file:///Users/ps/Documents/ibriz/git/engine_mcp/skills/sui-move-skills) (19 reference files across 3 skills)

---

## 1. Object Model

An **object** = struct with `key` ability + first field `id: UID`:

```move
public struct MyObject has key { id: UID, data: u64 }
```

### Ownership Types

| Type | How | Speed | Use For |
|------|-----|-------|---------|
| **Single-owner** | `transfer::transfer(obj, addr)` | Fast (~400ms) | Player assets, capabilities |
| **Shared** | `transfer::share_object(obj)` | Consensus (~2-3s) | Game state, registries |
| **Immutable** | `transfer::freeze_object(obj)` | Fast | Published configs |
| **Object-owned** | `transfer::transfer(obj2, id(&obj1).to_address())` | Fast | Hierarchical composition |

> ⚠️ Shared & frozen are **irreversible**. Prefer owned objects when possible.

---

## 2. Abilities & Common Combos

| Ability | Allows | Required For |
|---------|--------|-------------|
| `key` | Sui object (has UID) | On-chain objects |
| `store` | Storable inside other objects | Dynamic fields, collections |
| `copy` | Can duplicate | Value types |
| `drop` | Can discard | Witnesses, temps |

| Combo | Use Case | Example |
|-------|----------|---------|
| `key` | Standalone object | `Entity`, `AdminCap` |
| `key, store` | Nestable object | `Item`, `Accessory` |
| `store, copy, drop` | Lightweight component | `Health`, `Position` |
| `store, drop` | Component w/ String fields | `Metadata`, `Profile` |
| `copy, drop` | Event | `AttackEvent` |
| *(none)* | Hot Potato (must consume) | `Request`, `Promise` |

**Rules**: `key` → first field must be `id: UID`. Struct abilities ≤ field abilities.

---

## 3. Dynamic Fields

```move
use sui::dynamic_field as df;

df::add(&mut uid, name, value);        // attach (aborts if exists)
df::borrow(&uid, name): &Value         // read
df::borrow_mut(&mut uid, name): &mut Value  // mutate
df::remove(&mut uid, name): Value      // detach
df::remove_if_exists(&mut uid, name): Option<Value>  // safe remove
df::exists_(&uid, name): bool          // check
df::exists_with_type(&uid, name): bool // type-specific check
```

| | `dynamic_field` | `dynamic_object_field` |
|---|---|---|
| Value needs | `store` | `key + store` |
| Object ID preserved | No | Yes |
| Gas cost | Lower | ~2x |
| Use for | Component data | NFT items |

**Key type**: must have `copy + drop + store` (e.g., `vector<u8>`, `ascii::String`, `u64`)

> ⚠️ Deleting UID with attached fields = **permanently orphaned**. Remove fields first.

---

## 4. Collections

| Collection | Backed By | Size Limit | Iterable | When |
|-----------|-----------|-----------|----------|------|
| `vector<T>` | Memory | 256KB | ✅ | Small ordered lists |
| `VecSet<T>` | Vector | 256KB | ✅ | Small unique sets (<100) |
| `VecMap<K,V>` | Vector | 256KB | ✅ | Small KV maps (<100) |
| `Table<K,V>` | Dynamic fields | Unlimited | ❌ | Large KV maps |
| `Bag` | Dynamic fields | Unlimited | ❌ | Mixed-type collections |
| `ObjectTable<K,V>` | Dynamic object fields | Unlimited | ❌ | Object maps (IDs visible) |
| `ObjectBag` | Dynamic object fields | Unlimited | ❌ | Mixed-type object bags |
| `LinkedTable<K,V>` | Dynamic fields | Unlimited | Linked | Ordered maps, queues |
| `PriorityQueue<T>` | Vector | 256KB | Pop-only | Turn scheduling |

`ObjectTable`/`ObjectBag` mirror `Table`/`Bag` API but values must have `key + store` and their object IDs remain visible to explorers/indexers.

**Rule**: If it can grow unbounded → use `Table`/`Bag`/`LinkedTable`.

---

## 5. Design Patterns

### Capability — Authorization

```move
public struct AdminCap has key, store { id: UID }
public fun set_config(_cap: &AdminCap, ...) { ... } // ownership = authorization
```

### Witness — Module Identity Proof

```move
public struct MY_TOKEN has drop {}
fun init(witness: MY_TOKEN, ctx: &mut TxContext) { ... }
```

### One-Time Witness (OTW)

Must: match module name ALL CAPS, only `drop`, no fields, auto-passed to `init`.

### Hot Potato — Force Completion

```move
public struct MoveRequest { entity_id: ID } // NO abilities → must consume
public fun begin_move(...): MoveRequest { ... }
public fun complete_move(request: MoveRequest, ...) { ... } // consumes it
```

| Pattern | Solves | Engine Layer |
|---------|--------|-------------|
| Capability | Authorization | Admin controls |
| Witness | Module identity | Type registration, coins |
| OTW | One-time init | Registry setup |
| Hot Potato | Forced completion | Multi-step game actions |
| Wrapper | Extending foreign types | Adding metadata |

---

## 6. Visibility & API Design

| Modifier | Callable From | Removable on Upgrade |
|----------|--------------|---------------------|
| `public fun` | Anywhere | ❌ Never |
| `public(package) fun` | Same package | ✅ |
| `entry fun` | PTBs only (not composable) | ✅ |
| `fun` (private) | Same module | ✅ |

**Default**: `public fun` for composable APIs. `entry` only to prevent composability (e.g., randomness).

### Receiver Syntax (Move 2024)
```move
public fun current(self: &Health): u64 { self.current }
health.current();  // method-style call
```

### `init` Rules
- Private, named `init`, last param `&mut TxContext`
- Optional OTW as first param
- Runs **once** at publish

### Parameter Order
```
1. Objects (&mut App)  2. Capabilities (&AdminCap)
3. Values (amount: u64)  4. Clock (&Clock)  5. TxContext (&mut TxContext)
```

---

## 7. Framework API Quick Reference

### Object & Transfer
```move
object::new(ctx): UID              uid.delete()
object::id(&obj): ID               id.to_address(): address
transfer::transfer(obj, addr)      // same module, key
transfer::public_transfer(obj, addr) // any module, key+store
transfer::share_object(obj)        // irreversible shared
transfer::freeze_object(obj)       // irreversible immutable

// Receiving objects sent to a parent object
transfer::receive<T: key>(&mut parent_uid, Receiving<T>): T
transfer::public_receive<T: key+store>(&mut parent_uid, Receiving<T>): T
```

### Clock & Random
```move
clock.timestamp_ms(): u64           // shared singleton at 0x6, always &Clock
let mut gen = random::new_generator(r, ctx);  // r = singleton at 0x8
gen.generate_u64_in_range(min, max): u64
gen.generate_bool(): bool
gen.shuffle(&mut vector)
```

> ⚠️ Random consumers must be `entry fun` — never expose generator via `public`.

### Events
```move
event::emit(MyEvent { ... })  // MyEvent must have copy + drop
```

### Coin & Balance
```move
// Balance (store, no key) — embed in structs
balance::zero<T>(): Balance<T>
balance.split(amount): Balance<T>     balance.join(other): u64

// Coin (key+store) — user-facing transfers
coin::mint(&mut cap, amount, ctx): Coin<T>
coin::mint_balance(&mut cap, amount): Balance<T>  // cheaper, no object
coin::into_balance(coin): Balance<T>
coin::from_balance(bal, ctx): Coin<T>
coin::burn(&mut cap, coin): u64

// Convenience: Balance ↔ Coin helpers
coin::take(&mut balance, amount, ctx): Coin<T>  // take from balance as coin
coin::put(&mut balance, coin)                   // put coin into balance
```

**Rule**: `Balance<T>` inside structs, `Coin<T>` only for transfers.

### Math
```move
math::min(a, b)   math::max(a, b)   math::diff(a, b)  // |a-b|
math::pow(base, exp)   math::sqrt(x)   math::divide_and_round_up(x, y)
```

### Display — Object Metadata for Wallets/Explorers
```move
let mut display = display::new<MyType>(&publisher, ctx);
display.add(b"name".to_string(), b"{name}".to_string());
display.add(b"image_url".to_string(), b"{image_url}".to_string());
display.update_version();  // commit (makes active)
```

Templates use `{field_name}` to interpolate struct fields. Standard fields: `name`, `description`, `image_url`, `project_url`, `link`, `creator`, `thumbnail_url`. Requires `Publisher` (from `package::claim` in `init`).

---

## 8. Upgradeability

### Locked Forever (once published)
- Modules, `public struct` fields, `public fun` signatures, struct abilities

### Can Change
- `public fun` **body**, `public(package)` funs, `entry` funs, private funs, new modules/structs/fns

### Version Guard Pattern
```move
const VERSION: u8 = 1;
public struct SharedState has key { id: UID, version: u8 }
public fun mutate(state: &mut SharedState) {
    assert!(state.version == VERSION, EVersionMismatch);
}
```

### Config Anchoring
Minimal anchor struct + actual config as dynamic fields → fields can change shape on upgrade.

### Upgrade Policies (one-way restriction)
`Compatible` → `cap.only_additive_upgrades()` → `cap.only_dep_upgrades()` → `cap.make_immutable()`

---

## 9. Gas & Protocol Limits

| Limit | Value | Workaround |
|-------|-------|-----------|
| Transaction size | 128 KB | Split across txs |
| Object size | 256 KB | Use Table/Bag for overflow |
| Pure argument | 16 KB (~500 addrs) | Join vectors in PTB |
| Objects created/tx | 2,048 | Batch across txs |
| Dynamic fields created/tx | ~1,000 | Batch across txs |
| Dynamic fields accessed/tx | 1,000 | Minimize reads |
| Events/tx | 1,024 | Emit summaries |

### Gas Tips
- Borrow dynamic field **once**, reuse reference
- Use `Balance<T>` over `Coin<T>` in structs (no object overhead)
- Use `coin::mint_balance` instead of `coin::mint` + `into_balance`

---

## 10. Error Handling

```move
const ENotAuthorized: u64 = 0;    // EPascalCase, sequential from 0
assert!(condition, ENotAuthorized);
```

**Three Rules**:
1. Pre-check with your own codes, don't rely on downstream aborts
2. **Unique abort code per check** — never reuse
3. Public checks return `bool`; callers choose `assert!` or graceful skip

---

## 11. Code Quality & Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Module | `snake_case` | `combat_sys` |
| Struct | `PascalCase` | `Health`, `AdminCap` |
| Function | `snake_case` | `take_damage` |
| Error const | `E` + PascalCase | `ENotAuthorized` |
| Regular const | `ALL_CAPS` | `MAX_HEALTH` |
| Capability | `PascalCase` + `Cap` | `AdminCap` |
| Event | Past tense | `DamageDealt`, `EntitySpawned` |
| DF Key | Positional struct + `Key` | `HealthKey()` |

### Modern Syntax (Move 2024)
```move
id.delete();                    // not object::delete(id)
ctx.sender();                   // not tx_context::sender(ctx)
b"hello".to_string();           // not utf8(b"hello")
let v = vector[10, 20];        // not vector::empty() + push_back
items.do_ref!(|item| ...);     // not manual while loops
```

### Testing
- Test module: `#[test_only] module pkg::mod_tests;`
- No `test_` prefix on function names
- Use `assert_eq!` over `assert!` with abort codes
- `tx_context::dummy()` for simple contexts
- `test_utils::destroy(val)` for cleanup
- `#[test, expected_failure(abort_code = mod::EError)]` (combined)
- In `expected_failure` tests: end with `abort` not cleanup

---

## 12. Common Init Template

```move
module my_game::my_module;

public struct MY_MODULE has drop {}  // OTW

fun init(otw: MY_MODULE, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);
    transfer::share_object(GameConfig { id: object::new(ctx), version: 1 });
    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
    transfer::public_transfer(publisher, ctx.sender());
}
```
