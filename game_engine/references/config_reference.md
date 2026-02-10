# Config Registries — Best Practices

Game parameters should live in **shared Registry objects**, not hardcoded constants. This enables runtime tuning without redeploying packages.

## When to Use a Registry

- Unit stats (health, attack, defense per unit type)
- Game economy (resource costs, rewards, rates)
- Timing (cooldowns, durations, intervals)
- Limits (max inventory size, garrison cap, level requirements)

## Registry Pattern

```move
module my_package::health_config;

use sui::dynamic_field;
use std::ascii::{Self, String};

/// Shared config object — one per deployment
public struct Registry has key {
    id: UID,
    default_max_health: u64,
    regen_rate_per_second: u64,
}

/// Created automatically at package publish
fun init(ctx: &mut TxContext) {
    transfer::share_object(Registry {
        id: object::new(ctx),
        default_max_health: 100,
        regen_rate_per_second: 1,
    });
}

// ─── Setters ────────────────────────────
entry fun set_default_max_health(registry: &mut Registry, value: u64) {
    registry.default_max_health = value;
}

// ─── Getters ────────────────────────────
public fun default_max_health(registry: &Registry): u64 {
    registry.default_max_health
}
```

## Per-Key Config via Dynamic Fields

For variable data (e.g., stats per unit type, config per level):

```move
public struct UnitStats has drop, store {
    health: u128,
    attack: u128,
    defense: u128,
    speed: u128,
}

/// Set stats for a specific unit type
entry fun set_unit_stats(
    registry: &mut Registry,
    name: String,
    health: u128,
    attack: u128,
    defense: u128,
    speed: u128,
) {
    let stats = UnitStats { health, attack, defense, speed };
    if (!dynamic_field::exists_(&registry.id, name)) {
        dynamic_field::add(&mut registry.id, name, stats);
    } else {
        let existing: &mut UnitStats = dynamic_field::borrow_mut(&mut registry.id, name);
        *existing = stats;
    };
}

/// Read stats for a unit type
public fun unit_stats(registry: &Registry, name: String): (u128, u128, u128, u128) {
    let s: &UnitStats = dynamic_field::borrow(&registry.id, name);
    (s.health, s.attack, s.defense, s.speed)
}
```

## Best Practices

| Practice | Why |
|----------|-----|
| Use inline fields for simple global values | Cheap to read, easy to understand |
| Use dynamic fields for per-key data | Scales to any number of entries |
| Always add `#[test_only] init_for_testing()` | Tests need the registry initialized |
| Keep setters as `entry` functions | Callable from transactions for runtime tuning |
| Keep getters as `public` functions | Other packages need to read config |

## Test Helper

```move
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
```

## Checklist

- [ ] Define `Registry` struct with `has key`
- [ ] Implement `init()` to create and share it
- [ ] Add `entry` setter functions for each config value
- [ ] Add `public` getter functions
- [ ] Add `#[test_only] init_for_testing()`
- [ ] Use dynamic fields for per-key variable data
