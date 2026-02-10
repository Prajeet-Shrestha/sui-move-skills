# Systems — Best Practices

Systems are **stateless Move modules** that contain game logic. They read/write components on entities but hold no state themselves.

## System Package Structure

Separate concerns into distinct files:

```
packages/systems/combat_sys/
├── Move.toml              # Dependencies on entity + component packages
├── sources/
│   ├── entry.move         # Transaction entry points (public/entry functions)
│   ├── helpers.move       # Pure game logic (package-visible)
│   ├── events.move        # Event struct definitions + emit functions
│   └── version.move       # Version tracking placeholder
└── tests/
    └── combat_tests.move  # Unit tests
```

**Why this split?**
- `entry.move` — The "API layer": validates input, orchestrates calls, emits events
- `helpers.move` — The "logic layer": pure computation, reusable across entry points
- `events.move` — The "communication layer": defines what off-chain indexers see

## Entry Module Pattern

```move
module combat_sys::entry;

use std::ascii;
use sui::clock::Clock;
use entity::entity::{Entity};
use combat_sys::helpers;
use combat_sys::events;

// Import components
use health::health;
use position::position;

const EEntityDead: u64 = 0;

/// Attack another entity
public fun attack(
    attacker: &mut Entity,
    defender: &mut Entity,
    clock: &Clock,
) {
    // 1. Read components
    let atk_stats = health::borrow(attacker);
    assert!(atk_stats.current() > 0, EEntityDead);

    // 2. Compute (delegate to helpers)
    let damage = helpers::calculate_damage(attacker, defender);

    // 3. Mutate components
    let def_health = health::borrow_mut(defender);
    health::take_damage(def_health, damage);

    // 4. Emit event
    events::emit_attack_event(
        object::id(attacker),
        object::id(defender),
        damage,
        clock.timestamp_ms(),
    );
}
```

### Entry Function Best Practices

1. **Validate first** — Check preconditions before any mutations
2. **Delegate computation** — Complex logic → `helpers.move`
3. **Mutate at the end** — Read → compute → write pattern
4. **Always emit events** — Off-chain indexers depend on them

## Helpers Module Pattern

```move
module combat_sys::helpers;

use entity::entity::Entity;
use health::health;
use std::ascii;

/// Package-visible: only callable from entry.move
public(package) fun calculate_damage(
    attacker: &Entity,
    defender: &Entity,
): u64 {
    let atk = health::borrow(attacker);
    let def = health::borrow(defender);
    // Pure computation — no mutations
    let base_damage = atk.max() / 10;
    base_damage
}
```

### Function Visibility Guide

| Visibility | Use When |
|-----------|----------|
| `fun` | Private to the module |
| `public(package) fun` | Shared within the package (entry ↔ helpers) |
| `public fun` | Shared across packages (other systems can reuse) |
| `entry fun` | Directly callable from transactions |

## Accessing Components from Systems

```move
// Read via component module's convenience function
let health = health::borrow(entity);

// Or directly via entity's generic function
let health: &Health = entity.borrow_component<Health>(
    ascii::string(health::borrow_key())
);

// Mutate
let health = health::borrow_mut(entity);
health::take_damage(health, 10);

// Store simple values directly as dynamic fields
entity.add_component(ascii::string(b"attack_count"), 5u64);
let count: &mut u64 = entity.borrow_mut_component(ascii::string(b"attack_count"));
*count = *count - 1;
```

## Multi-Entity Systems (Composition)

Systems that compose an entity from multiple components:

```move
fun create_player(
    name: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let mut entity = entity::new(ascii::string(b"player"), clock, ctx);

    // Attach components
    health::add_component(health::new(100), &mut entity);
    position::add_component(position::new(0, 0), &mut entity);
    inventory::add_component(inventory::new(ctx), &mut entity);
    experience::add_component(experience::new(), &mut entity);
    timers::add_component(timers::new(), &mut entity);

    entity::share(entity);
}
```

## Anti-Patterns to Avoid

| ❌ Don't | ✅ Do Instead |
|----------|--------------|
| Store state in system modules | Systems are stateless; use components |
| Put all logic in entry functions | Delegate to `helpers.move` for reusability |
| Read and mutate the same component ref | Read first, compute, then get mutable ref |
| Skip events | Always emit events — indexers depend on them |
| Import component key strings directly | Use `component::borrow_key()` functions |

## Checklist for New Systems

- [ ] Create `packages/systems/my_sys/` directory
- [ ] Set up `Move.toml` with entity + component dependencies
- [ ] `entry.move`: Transaction entry points with validate → compute → mutate → emit pattern
- [ ] `helpers.move`: `public(package)` computation functions
- [ ] `events.move`: Event struct definitions + emit functions
- [ ] `version.move`: Placeholder for upgrade versioning
- [ ] `tests/`: Unit tests using `test_scenario`
