# Code Quality

> Source: [Move Book — Code Quality Checklist](https://move-book.com/guides/code-quality-checklist)

## Module & Imports

### Module Declaration

```move
// ✅ Modern style (flat, no indentation)
module my_package::my_module;

// ❌ Legacy style (unnecessary nesting)
module my_package::my_module { ... }
```

### Import Conventions

```move
// ✅ Group Self with members
use my_package::my_module::{Self, SomeType};

// ❌ Separate imports for same module
use my_package::my_module;
use my_package::my_module::SomeType;

// ❌ Redundant {Self}
use my_package::my_module::{Self};
// ✅ Just:
use my_package::my_module;
```

---

## Constants

```move
// Error constants: EPascalCase
const ENotAuthorized: u64 = 0;
const EInvalidInput: u64 = 1;

// Regular constants: ALL_CAPS
const MAX_HEALTH: u64 = 100;
const COOLDOWN_MS: u64 = 5000;
const VERSION: u8 = 1;
```

---

## Structs

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Capabilities | Suffix with `Cap` | `AdminCap`, `TreasuryCap` |
| Events | Past tense | `DamageDealt`, `EntitySpawned` |
| Hot Potato | No "Potato" in name | `Promise`, `Receipt` (not `PromisePotato`) |
| Dynamic field keys | Positional struct + `Key` suffix | `HealthKey()` |

```move
// ✅ Event naming
public struct EntitySpawned has copy, drop { entity_id: ID }
public struct DamageDealt has copy, drop { amount: u64 }

// ❌ Wrong event naming
public struct SpawnEntity has copy, drop { ... }    // imperative, not past tense
public struct DealDamage has copy, drop { ... }     // imperative

// ✅ Dynamic field key using positional struct
public struct HealthKey() has copy, drop, store;

// ❌ Legacy dynamic field key
public struct HealthKey has copy, drop, store {}
```

---

## Functions

### Visibility Rules

```move
// ✅ PREFER: public fun — composable, usable in PTBs, can return values
public fun mint(ctx: &mut TxContext): NFT { ... }

// ❌ AVOID: public entry — entry modifier is redundant for public funs
public entry fun mint_item(ctx: &mut TxContext) { ... }

// ✅ OK: entry (non-public) — when you want to prevent composability
entry fun consume_random(r: &Random, ctx: &mut TxContext) { ... }
```

### Parameter Order

```
1. Objects (main resource)    — &mut App, &Entity
2. Capabilities              — &AdminCap
3. Value arguments           — amount: u64, name: String
4. Clock (always last object) — &Clock
5. TxContext (always last)    — &mut TxContext
```

```move
// ✅ Correct order
public fun create_item(
    inventory: &mut Inventory,   // 1. main object
    cap: &AdminCap,              // 2. capability
    name: String,                // 3. value args
    amount: u64,                 // 3. value args
    clock: &Clock,               // 4. clock
    ctx: &mut TxContext,         // 5. context
) { ... }
```

### Getters

```move
// ✅ Named after field (no `get_` prefix)
public fun name(u: &User): String { u.name }
public fun health(e: &Entity): u64 { ... }

// ✅ Mutable getters use `_mut` suffix
public fun details_mut(u: &mut User): &mut Details { &mut u.details }

// ❌ Unnecessary prefix
public fun get_name(u: &User): String { ... }
```

---

## Method Syntax & Macros

### Use Struct Methods

```move
// ❌ Legacy function calls
object::delete(id);
tx_context::sender(ctx);
coin::split(&mut payment, amount, ctx);

// ✅ Method syntax
id.delete();
ctx.sender();
payment.split(amount, ctx);
```

### String Literals

```move
// ❌ Importing utf8
use std::string::utf8;
let s = utf8(b"hello");

// ✅ Method on byte literal
let s = b"hello".to_string();
let ascii = b"hello".to_ascii_string();
```

### Vector Operations

```move
// ❌ Legacy vector ops
let mut v = vector::empty();
vector::push_back(&mut v, 10);
let first = vector::borrow(&v, 0);

// ✅ Modern syntax
let mut v = vector[10];
let first = v[0];
assert!(v.length() == 1);
```

### Loop Macros (prefer over manual loops)

```move
// Repeat N times
32u8.do!(|_| do_action());

// Create vector from iteration
let ids = vector::tabulate!(32, |i| i);

// Iterate by reference
items.do_ref!(|item| process(item));

// Iterate by mutable reference
items.do_mut!(|item| item.level = item.level + 1);

// Destroy vector, calling function on each element
items.destroy!(|item| consume(item));

// Fold
let total = values.fold!(0u64, |acc, v| acc + v);

// Filter (T must have drop)
let alive = entities.filter!(|e| e.health > 0);
```

### Collection Index Syntax

```move
// ❌ Method call
vec_map.get(&key);

// ✅ Index syntax
&vec_map[&key];
&mut vec_map[&key];
```

---

## Testing Conventions

### Test Structure

```move
#[test_only]
module my_package::my_module_tests;

// ✅ No test_ prefix (module name already says it's tests)
#[test]
fun entity_spawns_with_correct_health() { ... }

// ❌ Redundant prefix
#[test]
fun test_entity_spawns() { ... }
```

### Merge Annotations

```move
// ❌ Separate annotations
#[test]
#[expected_failure(abort_code = my_module::ENotAuthorized)]
fun unauthorized_access_fails() { ... }

// ✅ Combined
#[test, expected_failure(abort_code = my_module::ENotAuthorized)]
fun unauthorized_access_fails() { ... }
```

### expected_failure Tests: Don't Clean Up

```move
// ❌ BAD: unnecessary cleanup
#[test, expected_failure(abort_code = my_module::ENotAuthorized)]
fun unauthorized_fails() {
    let mut test = ts::begin(@0);
    my_module::restricted_action(test.ctx());
    test.end(); // unreachable, but makes it unclear where failure is expected
}

// ✅ GOOD: abort explicitly to clarify where test should fail
#[test, expected_failure(abort_code = my_module::ENotAuthorized)]
fun unauthorized_fails() {
    let mut test = ts::begin(@0);
    my_module::restricted_action(test.ctx());
    abort  // clearly: test should have failed before this
}
```

### Use `tx_context::dummy()` when possible

```move
// ❌ Full scenario just for a context
let mut test = ts::begin(@0);
let item = create_item(test.ctx());
item.destroy();
test.end();

// ✅ Simple dummy context
let ctx = &mut tx_context::dummy();
create_item(ctx).destroy();
```

### Assertions in Tests

```move
// ❌ Don't use abort codes in test assertions (may collide with app errors)
assert!(health == 100, 0);

// ✅ No abort code needed in tests
assert!(health == 100);

// ✅ Even better: use assert_eq! (prints both values on failure)
use std::unit_test::assert_eq;
assert_eq!(health, 100);
```

### Use `sui::test_utils::destroy` for Cleanup

```move
use sui::test_utils;

// ✅ Destroy any value in tests without worrying about abilities
test_utils::destroy(some_object);
```
