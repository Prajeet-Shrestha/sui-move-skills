# Storage Modules

> Covers `sui::object`, `sui::dynamic_field`, `sui::dynamic_object_field`, `sui::transfer`

## `sui::object` — Object Identity

Every Sui object needs a globally unique `UID`. This module creates and manages them.

### Key Types

```move
/// Globally unique identifier. Every object struct has one.
/// Cannot be copied, dropped, or stored — must be explicitly created and deleted.
public struct UID has store { ... }

/// Copyable object identifier. Use for lookups and references.
public struct ID has copy, drop, store { ... }
```

### Essential Functions

```move
// Create a new UID (requires TxContext)
public fun new(ctx: &mut TxContext): UID

// Delete a UID (required before dropping an object)
uid.delete()

// Get ID from any object with `key`
public fun id<T: key>(obj: &T): ID

// Get ID by reference
public fun borrow_id<T: key>(obj: &T): &ID

// UID → ID conversions
uid.to_inner(): ID              // copies
uid.as_inner(): &ID             // borrows

// ID → address/bytes
id.to_address(): address
id.to_bytes(): vector<u8>

// UID → address/bytes (shorthand)
uid.to_address(): address
uid.to_bytes(): vector<u8>

// Reconstruct ID from address or bytes
public fun id_from_address(a: address): ID
public fun id_from_bytes(bytes: vector<u8>): ID
```

### Engine Usage

```move
public struct Entity has key {
    id: UID,          // created via object::new(ctx)
    `type`: String,
    created_at: u64,
}

// In destructor:
public fun destroy(entity: Entity) {
    let Entity { id, .. } = entity;
    id.delete(); // MUST delete UID explicitly
}
```

---

## `sui::dynamic_field` — Component Attachment

Dynamic fields attach data to any `UID` at runtime. This is the **core mechanism** for ECS component attachment.

### API Summary

| Function | Signature | Notes |
|----------|-----------|-------|
| `add` | `add<Name: copy+drop+store, Value: store>(&mut UID, name, value)` | Aborts if field exists |
| `borrow` | `borrow<Name, Value>(&UID, name): &Value` | Immutable read |
| `borrow_mut` | `borrow_mut<Name, Value>(&mut UID, name): &mut Value` | Mutable read |
| `remove` | `remove<Name, Value>(&mut UID, name): Value` | Returns the value |
| `exists_` | `exists_<Name: copy+drop+store>(&UID, name): bool` | Type-erased check |
| `exists_with_type` | `exists_with_type<Name, Value>(&UID, name): bool` | Type-specific check |
| `remove_if_exists` | `remove_if_exists<Name, Value>(&mut UID, name): Option<Value>` | Safe remove |

### Key Constraints

- **Name** must have `copy + drop + store`
- **Value** must have `store` (but NOT `key` required)
- A field keyed by `(Name_type, name_value)` is unique per object
- Dynamic fields are **lazy-loaded** — only accessed fields cost gas

### Engine Pattern: Component Keys

```move
use std::ascii::String;

// Components use ascii::String keys
const HEALTH_KEY: vector<u8> = b"health";

public fun add_health(entity: &mut Entity, health: Health) {
    df::add(entity.uid_mut(), HEALTH_KEY.to_ascii_string(), health);
}

public fun borrow_health(entity: &Entity): &Health {
    df::borrow(entity.uid(), HEALTH_KEY.to_ascii_string())
}

public fun has_health(entity: &Entity): bool {
    df::exists_(entity.uid(), HEALTH_KEY.to_ascii_string())
}
```

---

## `sui::dynamic_object_field` — Object-Preserving Attachment

Same API as `dynamic_field`, but values **must have `key + store`** and their object identity is preserved in global storage.

### When to Use Which

| Feature | `dynamic_field` | `dynamic_object_field` |
|---------|----------------|----------------------|
| Value constraint | `store` | `key + store` |
| Object ID preserved | No (wrapped) | Yes (visible to explorers) |
| Off-chain lookup by ID | Not possible | Possible |
| Gas cost | Lower | ~2x (extra object lookup) |
| Use for | Component data, primitives | NFT items, transferable objects |

### API (mirrors `dynamic_field`)

```move
use sui::dynamic_object_field as dof;

// Same function names, different constraints
dof::add<Name: copy+drop+store, Value: key+store>(&mut UID, name, value)
dof::borrow<Name, Value>(&UID, name): &Value
dof::borrow_mut<Name, Value>(&mut UID, name): &mut Value
dof::remove<Name, Value>(&mut UID, name): Value
dof::exists_<Name>(&UID, name): bool
dof::exists_with_type<Name, Value>(&UID, name): bool

// Extra: get the ID of the stored object without borrowing it
dof::id<Name: copy+drop+store>(&UID, name): Option<ID>
```

### Engine Pattern: Equipment Slots

```move
// Equipment is an object (key + store) — use dof
dof::add(&mut entity.id, b"weapon".to_ascii_string(), sword);

// Components are pure data (store) — use df
df::add(&mut entity.id, b"health".to_ascii_string(), health);
```

---

## `sui::transfer` — Ownership Management

Controls how objects are owned: single-owner, shared, or frozen.

### Transfer Functions

| Function | Constraint | Use |
|----------|-----------|-----|
| `transfer<T: key>(obj, recipient)` | Same module only | Internal ownership assignment |
| `public_transfer<T: key+store>(obj, recipient)` | Any module | Cross-module transfer |
| `share_object<T: key>(obj)` | Same module only | Make shared (irreversible) |
| `public_share_object<T: key+store>(obj)` | Any module | Cross-module sharing |
| `freeze_object<T: key>(obj)` | Same module only | Make immutable (irreversible) |
| `public_freeze_object<T: key+store>(obj)` | Any module | Cross-module freezing |

### `transfer` vs `public_transfer`

```move
// WITHIN the defining module — use non-public variants
// (works for types without `store`)
public struct Entity has key { id: UID, ... }

fun init(ctx: &mut TxContext) {
    let entity = Entity { id: object::new(ctx), ... };
    transfer::transfer(entity, ctx.sender()); // OK: same module
}

// FROM ANOTHER module — must use public variants
// (requires `store` ability on the type)
public struct Item has key, store { id: UID, ... }

public fun give_item(item: Item, to: address) {
    transfer::public_transfer(item, to); // OK: Item has store
}
```

### Receiving Objects

```move
// Struct for receiving transferred objects
public struct Receiving<phantom T: key> has drop { ... }

// Receive an object transferred to a parent object
public fun receive<T: key>(parent: &mut UID, to_receive: Receiving<T>): T
public fun public_receive<T: key+store>(parent: &mut UID, to_receive: Receiving<T>): T
```

### Engine Pattern: Entity Lifecycle

```move
// Create and transfer to player
public fun spawn(ctx: &mut TxContext) {
    let entity = entity::new(b"character", clock, ctx);
    transfer::transfer(entity, ctx.sender());
}

// Share game state
public fun create_world(ctx: &mut TxContext) {
    let registry = Registry { id: object::new(ctx), ... };
    transfer::share_object(registry); // anyone can access
}

// Freeze config template
public fun publish_template(template: Template) {
    transfer::freeze_object(template); // read-only forever
}
```
