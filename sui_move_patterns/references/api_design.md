# API Design Conventions

> Source: [Move Book Ch 5.15, 5.18–5.20, 8.2–8.3](https://move-book.com/move-basics/)

## Visibility Modifiers

### Summary

| Modifier | Callable From | Use For |
|----------|--------------|---------|
| (none) | Same module only | Private helpers, internal logic |
| `public(package)` | Any module in the same package | Cross-module coordination within a system |
| `public` | Any module in any package | Engine API, reusable utilities |
| `entry` | Transactions only (not from other Move code) | Top-level PTB endpoints |

### `public` vs `entry`

Both can be called from transactions, but:
- `public` functions can also be called from other Move modules
- `entry` functions can **only** be called from transactions (cannot be composed in Move)
- A function can be both: `public entry fun` (callable from both)

**Convention**: Prefer `public` for composability. Use `entry` only when a function should never be called from other Move code (e.g., admin-only setup functions).

### `public(package)` — Cross-Module Helpers

Essential for the system pattern (entry + helpers + events in the same package):

```move
// helpers.move — only callable from entry.move in the same package
public(package) fun calculate_damage(atk: u64, def: u64): u64 {
    if (atk > def) { atk - def } else { 0 }
}

// events.move — only callable from within the system package
public(package) fun emit_attack(attacker: ID, defender: ID, damage: u64) {
    event::emit(AttackEvent { attacker, defender, damage });
}
```

## Struct Methods (Receiver Syntax)

Move 2024 supports method-style calls on structs:

```move
public struct Health has store, copy, drop {
    current: u64,
    max: u64,
}

// Define as a method using `self`
public fun current(self: &Health): u64 { self.current }
public fun is_alive(self: &Health): bool { self.current > 0 }
public fun take_damage(self: &mut Health, amount: u64) { ... }

// Call using method syntax
let hp = health.current();
let alive = health.is_alive();
health.take_damage(10);
```

**Convention**: Use receiver syntax for all getters and setters on components. Makes code read naturally and is consistent across all component types.

## Module Initializer (`init`)

The `init` function runs **once** at package publish. Used for one-time setup.

```move
fun init(ctx: &mut TxContext) {
    // Create and share a registry
    transfer::share_object(Registry {
        id: object::new(ctx),
        max_health: 100,
    });

    // Create and transfer admin capability
    transfer::transfer(
        AdminCap { id: object::new(ctx) },
        ctx.sender()
    );
}
```

**Rules:**
- Must be named `init`
- Must be private (no visibility modifier)
- Takes `&mut TxContext` as the last parameter
- Optionally takes a One-Time Witness as the first parameter
- Cannot be called manually — only runs at publish

**Test helper convention:**
```move
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
```

## Transaction Context

`TxContext` provides transaction metadata:

```move
// Get the sender's address
let sender: address = ctx.sender();

// Get the current epoch
let epoch: u64 = ctx.epoch();

// Generate a new UID (for creating objects)
let uid = object::new(ctx);
```

## Enums and Match (Move 2024)

Enums allow representing states with associated data:

```move
public enum GameState has store, copy, drop {
    Waiting,
    InProgress { round: u64 },
    Finished { winner: address },
}

// Pattern matching
public fun describe(state: &GameState): String {
    match (state) {
        GameState::Waiting => b"waiting".to_string(),
        GameState::InProgress { round } => b"round".to_string(),
        GameState::Finished { winner } => b"finished".to_string(),
    }
}
```

**Engine use case**: Entity status, game phases, action types.

## Error Conventions

```move
// Module-scoped error constants
const EEntityDead: u64 = 0;
const EOutOfRange: u64 = 1;
const EInsufficientStamina: u64 = 2;

// Use with assert!
assert!(health.is_alive(), EEntityDead);
```

**Convention:**
- Prefix with `E` (e.g., `ENotAuthorized`)
- Use `u64` constants starting from 0
- Define at the top of the module
- Use `assert!` for all precondition checks

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Module | `snake_case` | `combat_sys`, `health` |
| Struct | `PascalCase` | `Health`, `AdminCap`, `AttackEvent` |
| Function | `snake_case` | `take_damage`, `borrow_key` |
| Constant | `PascalCase` with `E` prefix (errors) | `ENotAuthorized` |
| Type parameter | Single uppercase letter | `T`, `K`, `V` |
| Capability | `PascalCase` + `Cap` suffix | `AdminCap`, `MinterCap` |
| Event | `PascalCase` + `Event` suffix | `AttackEvent`, `MoveEvent` |
