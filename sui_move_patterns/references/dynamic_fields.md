# Dynamic Fields

> Source: [Move Book Ch 8.8–8.10](https://move-book.com/programmability/dynamic-fields)

## Two Types of Dynamic Fields

### `sui::dynamic_field` (df)

Stores any value (with `store`) as a field on an object's UID.

```move
use sui::dynamic_field as df;

// Add
df::add(&mut obj.id, b"health", Health { current: 100, max: 100 });

// Read
let health: &Health = df::borrow(&obj.id, b"health");

// Modify
let health: &mut Health = df::borrow_mut(&mut obj.id, b"health");

// Remove
let health: Health = df::remove(&mut obj.id, b"health");

// Check existence
let exists: bool = df::exists_(&obj.id, b"health");
```

**Internal storage**: Creates a `Field<Name, Value>` object under the hood. The field ID is deterministic: `hash(parent.id || name || Name_type)`.

**Key type constraints**: Name must have `copy + drop + store`.

### `sui::dynamic_object_field` (dof)

Same API but Value must have `key + store` (must be an object).

```move
use sui::dynamic_object_field as dof;

// Value must be an object (has key + store)
dof::add(&mut obj.id, b"weapon", Sword { id: object::new(ctx) });

// Can get the ID without loading the object
let sword_id: Option<ID> = dof::id(&obj.id, b"weapon");
```

## When to Use Which

| Scenario | Use | Reason |
|----------|-----|--------|
| ECS components (pure data) | `dynamic_field` | Components are data, not objects. Cheaper. |
| Nested objects that need ID lookup | `dynamic_object_field` | Preserves object identity for off-chain indexing |
| Simple key-value data | `dynamic_field` | Lower cost, simpler |

**Cost comparison**: Dynamic object fields cost ~2x because they create 2 objects internally (a Wrapper + the Value).

## Field Name Types

Any type with `copy + drop + store` can be a key:

```move
// Common: byte string literal → vector<u8>
df::add(&mut id, b"health", data);

// Also valid: ascii::String
df::add(&mut id, ascii::string(b"health"), data);

// Also valid: u64, bool, address, custom structs
df::add(&mut id, 42u64, data);
```

**Convention for ECS**: Use `ascii::String` keys from a `borrow_key()` function in each component module.

## UID Exposure — Security Model

Dynamic fields attach to a UID. Who you expose it to determines who can read/write fields.

```move
// SAFE: Read-only access to UID
public fun uid(obj: &MyObject): &UID { &obj.id }

// DANGEROUS: Mutable UID lets anyone add/remove fields
public fun uid_mut(obj: &mut MyObject): &mut UID { &mut obj.id }
```

**Best practice for ECS**: The entity package exposes generic `add_component` / `borrow_component` / `borrow_mut_component` functions that pass the UID internally. External packages never get raw `&mut UID`.

## Limits

- **Max 1000 dynamic fields created per transaction** (not per object — across all objects in the tx)
- **No object size limit** — dynamic fields are stored separately, so the parent object stays small
- **No iteration** — you cannot enumerate all dynamic fields on an object (must know the key)

## Orphaned Fields

If a parent UID is deleted while dynamic fields are still attached, those fields become **permanently inaccessible**.

```move
// DON'T DO THIS:
let MyObject { id } = obj;
id.delete();  // All dynamic fields on this UID are now orphaned!
```

**Prevention**: Remove all dynamic fields before deleting the UID, or use `Bag` which tracks its contents.

## Dynamic Collections (Table, Bag)

For large collections built on dynamic fields, see [collections.md](./collections.md).
