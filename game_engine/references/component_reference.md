# Components — Best Practices

Components are **pure data structs** attached to entities via dynamic fields. Each component module is self-contained: it owns its struct definition, its key, constructors, and entity attachment logic.

## Component Module Structure

Every component module should follow this pattern:

```move
module my_package::health;

use std::ascii::{Self, String};
use entity::entity::{Entity};

// ─── Struct ─────────────────────────────
public struct Health has store, copy, drop {
    current: u64,
    max: u64,
}

// ─── Key ────────────────────────────────
public fun borrow_key(): vector<u8> { b"health" }

// ─── Constructor ────────────────────────
public fun new(max: u64): Health {
    Health { current: max, max }
}

// ─── Entity Integration ─────────────────
public fun add_component(health: Health, entity: &mut Entity) {
    entity.add_component(ascii::string(borrow_key()), health);
}

public fun borrow(entity: &Entity): &Health {
    entity.borrow_component<Health>(ascii::string(borrow_key()))
}

public fun borrow_mut(entity: &mut Entity): &mut Health {
    entity.borrow_mut_component<Health>(ascii::string(borrow_key()))
}

// ─── Getters ────────────────────────────
public fun current(self: &Health): u64 { self.current }
public fun max(self: &Health): u64 { self.max }

// ─── Setters ────────────────────────────
public fun take_damage(self: &mut Health, amount: u64) {
    if (amount >= self.current) { self.current = 0; }
    else { self.current = self.current - amount; };
}

public fun heal(self: &mut Health, amount: u64) {
    self.current = std::u64::min(self.current + amount, self.max);
}
```

## Choosing Struct Abilities

| Abilities | Use When | Examples |
|-----------|----------|---------|
| `store, copy, drop` | Simple value types, stats, counters | Health, Position, Experience |
| `store, drop` | Types with non-copyable fields (`String`, `Url`) | Identity, Description |
| `key, store` | Component needs its own UID for nested dynamic fields | Inventory, Equipment slots |
| `store` | Must be explicitly destroyed (ownership semantics) | Tradeable items, tokens |

**Best practice:** Start with `store, copy, drop` unless you have a reason not to. `copy` enables efficient reads, `drop` avoids cleanup headaches.

## The Key Function Pattern

Every component exposes its dynamic field key as a function:

```move
public fun borrow_key(): vector<u8> { b"health" }
```

**Why a function, not a constant?**
- Functions are callable from other modules; Move constants are module-private
- Prevents key string typos across modules
- Single source of truth for the key

**Naming convention:** `borrow_key()` or `borrow_<component_name>_key()`.

## Component Categories

### 1. Value Components
Simple structs holding numeric or boolean data.

```move
public struct Experience has store, copy, drop {
    points: u128,
}
```

### 2. Map Components
Use `VecMap` for named sub-values (resources, cooldowns, unit counts).

```move
public struct ResourceStorage has store, drop {
    resources: VecMap<String, u128>,  // "cash" → 1000, "wood" → 500
}

public struct Timers has store, drop {
    cooldowns: VecMap<String, u64>,   // "attack" → expiry_timestamp
}

public struct Garrison has store, copy, drop {
    units: VecMap<String, u64>,       // "soldier" → 10, "archer" → 5
    limit: u64,
}
```

### 3. Container Components
Need their own `UID` for heterogeneous storage via nested dynamic fields.

```move
public struct Inventory has key, store {
    id: UID,  // For nested dynamic fields
}

// Items stored as dynamic fields on the inventory's UID
public fun add_item<T: key + store>(
    inventory: &mut Inventory,
    key: String,
    item: T,
) {
    dynamic_field::add(&mut inventory.id, key, item);
}
```

### 4. Config-Derived Components
Initialized from a shared Registry with game parameters.

```move
public fun new_from_registry(registry: &Registry): ResourceStorage {
    let mut storage = ResourceStorage { resources: vec_map::empty() };
    storage.resources.insert(ascii::string(b"cash"), registry.initial_cash());
    storage.resources.insert(ascii::string(b"wood"), registry.initial_wood());
    storage
}
```

## Anti-Patterns to Avoid

| ❌ Don't | ✅ Do Instead |
|----------|--------------|
| Put game data in the Entity struct | Use components attached via dynamic fields |
| Hardcode key strings in system modules | Import `borrow_key()` from the component module |
| Put business logic in components | Keep components data-only; logic goes in systems |
| Use `u8` enums without accessor functions | Provide typed getter functions |
| Forget `#[test_only]` helpers | Add test constructors that skip auth/config deps |

## Checklist for New Components

- [ ] Define struct with appropriate abilities
- [ ] Add `borrow_key()` function returning a unique `vector<u8>`
- [ ] Add `new()` constructor
- [ ] Add `add_component()` that attaches to entity using the key
- [ ] Add `borrow()` and `borrow_mut()` for entity access
- [ ] Add getter functions for each field
- [ ] Add setter/mutation functions
- [ ] Add `#[test_only]` helpers
- [ ] Set up `Move.toml` with `entity` dependency
