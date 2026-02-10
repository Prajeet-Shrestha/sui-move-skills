# Error Handling

> Source: [Move Book — Better Error Handling](https://move-book.com/guides/better-error-handling)

## Error Constants Convention

Error constants use **EPascalCase** naming and are `u64` typed.

```move
// ✅ Correct naming
const ENotAuthorized: u64 = 0;
const EEntityNotFound: u64 = 1;
const EHealthBelowZero: u64 = 2;
const ECooldownActive: u64 = 3;
const EInvalidAmount: u64 = 4;

// ❌ Wrong naming
const NOT_AUTHORIZED: u64 = 0;   // ALL_CAPS is for regular constants
const eNotFound: u64 = 1;        // wrong casing
```

---

## Three Rules of Error Handling

### Rule 1: Handle All Possible Scenarios

Don't rely on downstream functions to abort for you. Pre-check and use your own error codes.

```move
// ❌ BAD: relies on df::borrow to abort with a vague error
public fun get_health(entity: &Entity): &Health {
    df::borrow(entity.uid(), HEALTH_KEY) // aborts with generic dynamic_field error
}

// ✅ GOOD: check first, abort with descriptive code
const EHealthComponentMissing: u64 = 0;

public fun get_health(entity: &Entity): &Health {
    assert!(df::exists_(entity.uid(), HEALTH_KEY), EHealthComponentMissing);
    df::borrow(entity.uid(), HEALTH_KEY)
}
```

### Rule 2: Use Unique Abort Codes per Check

Never reuse the same abort code for different failure conditions.

```move
// ❌ BAD: same error code for different checks
const EInvalid: u64 = 0;

public fun attack(attacker: &Entity, defender: &Entity, clock: &Clock) {
    assert!(has_health(attacker), EInvalid);      // which one failed?
    assert!(has_health(defender), EInvalid);       // same code!
    assert!(is_alive(attacker), EInvalid);         // impossible to tell
}

// ✅ GOOD: unique codes for each condition
const EAttackerMissingHealth: u64 = 0;
const EDefenderMissingHealth: u64 = 1;
const EAttackerDead: u64 = 2;
const EDefenderDead: u64 = 3;
const ECooldownActive: u64 = 4;

public fun attack(attacker: &Entity, defender: &Entity, clock: &Clock) {
    assert!(has_health(attacker), EAttackerMissingHealth);
    assert!(has_health(defender), EDefenderMissingHealth);
    assert!(is_alive(attacker), EAttackerDead);
    assert!(is_alive(defender), EDefenderDead);
    assert!(cooldown_ready(attacker, clock), ECooldownActive);
}
```

### Rule 3: Return `bool` from Checks (not `assert`)

Expose check functions that return `bool` so callers can handle errors their way.

```move
// ❌ BAD: asserting inside a public check function
public fun assert_is_alive(entity: &Entity) {
    assert!(health::borrow(entity).current() > 0, EEntityDead);
}

// ✅ GOOD: return bool, let callers decide
public fun is_alive(entity: &Entity): bool {
    health::borrow(entity).current() > 0
}

// Callers choose their error handling:
public fun attack(...) {
    assert!(is_alive(attacker), EAttackerDead);  // custom error code
}

public fun heal(...) {
    if (!is_alive(target)) return;  // graceful skip instead of abort
}
```

**Private assert helpers are OK** for reducing duplication within the same module:

```move
// OK: private helper for repeated checks within this module
fun assert_is_alive(entity: &Entity) {
    assert!(is_alive(entity), EEntityDead);
}
```

---

## Error Code Organization

### Per-Module Convention

Each module should number its error codes sequentially starting from 0.

```move
module game::combat_sys;

// Error codes for this module (0-indexed, sequential)
const EAttackerMissingHealth: u64 = 0;
const EDefenderMissingHealth: u64 = 1;
const EAttackerDead: u64 = 2;
const ECooldownActive: u64 = 3;
const EInsufficientDamage: u64 = 4;
```

### Error Code Ranges (Optional — for larger projects)

For projects with many modules, reserve ranges per module:

```move
// combat_sys: 0-99
// movement_sys: 100-199
// inventory_sys: 200-299
```

This makes it easy to identify which module aborted from the error code alone.

---

## Engine Pattern: Guard Functions

```move
/// Reusable guard that checks entity validity before any system operation
public fun assert_entity_ready(
    entity: &Entity,
    clock: &Clock,
) {
    assert!(entity.is_alive(), EEntityDead);
    assert!(entity.cooldown_ready(clock), ECooldownActive);
}

/// System entry points call this first
public fun attack(
    attacker: &mut Entity,
    defender: &mut Entity,
    clock: &Clock,
) {
    assert_entity_ready(attacker, clock);
    assert_entity_ready(defender, clock);
    // ... combat logic
}
```
