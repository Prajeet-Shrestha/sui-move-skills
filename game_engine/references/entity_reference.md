# Entity — Best Practices

An Entity is a **lightweight Sui object** that serves as a container for components. It holds no game data itself — components are attached via dynamic fields.

## Entity Struct

```move
module entity::entity;

use std::ascii::String;
use sui::dynamic_field;
use sui::clock::Clock;

public struct Entity has key {
    id: UID,
    `type`: String,       // e.g. b"player", b"npc", b"building"
    created_at: u64,
}
```

**Best practices:**
- Entity has `key` only (not `store`) — it's always a top-level Sui object
- Keep the struct minimal: ID, type, timestamp. Nothing else.
- The `type` field enables cheap filtering without loading components

## Creating Entities

```move
public fun new(type: String, clock: &Clock, ctx: &mut TxContext): Entity {
    Entity {
        id: object::new(ctx),
        `type`: type,
        created_at: clock.timestamp_ms(),
    }
}

// Most game entities should be shared so any transaction can operate on them
public fun share(entity: Entity) {
    transfer::share_object(entity);
}
```

## Attaching & Accessing Components

All component operations go through dynamic fields, keyed by `ascii::String`:

```move
use std::ascii;

// Attach a component
entity.add_component(ascii::string(b"health"), health_component);

// Read (immutable)
let health: &Health = entity.borrow_component<Health>(ascii::string(b"health"));

// Write (mutable)
let health: &mut Health = entity.borrow_mut_component<Health>(ascii::string(b"health"));

// Remove
let health: Health = entity.remove_mut_component<Health>(ascii::string(b"health"));

// Check existence
let has_health: bool = entity.has_component(ascii::string(b"health"));
```

**Best practice:** These should be thin wrappers around `dynamic_field::add`, `dynamic_field::borrow`, etc.:

```move
public fun add_component<T: store>(entity: &mut Entity, key: String, value: T) {
    dynamic_field::add(&mut entity.id, key, value);
}

public fun borrow_component<T: store>(entity: &Entity, key: String): &T {
    dynamic_field::borrow(&entity.id, key)
}

public fun borrow_mut_component<T: store>(entity: &mut Entity, key: String): &mut T {
    dynamic_field::borrow_mut(&mut entity.id, key)
}

public fun has_component(entity: &Entity, key: String): bool {
    dynamic_field::exists_(&entity.id, key)
}
```

## Entity Lifecycle

```
Create  →  Attach components  →  Share  →  Systems read/write  →  (optional) Destroy
```

## Key Decisions

| Decision | Recommendation | Why |
|----------|---------------|-----|
| `key` vs `key, store` | Use `key` only | Entities shouldn't be nested inside other objects |
| Own vs Share | Share most entities | Game entities need to be accessed across transactions |
| Type field | Use `ascii::String` | Enables filtering without loading dynamic fields |
| Timestamp | Store `created_at` | Useful for time-based game mechanics |
