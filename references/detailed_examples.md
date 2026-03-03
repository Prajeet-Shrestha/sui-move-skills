# Sui Move — Detailed Examples & Edge Cases

> Deep-dive companion to [SKILL.md](../SKILL.md). Contains full working code examples, security rules, testing boilerplate, and edge cases not covered in the cheatsheet.

---

## Object Lifecycle — Entity Pattern

```move
public struct Entity has key {
    id: UID,
    `type`: String,
    created_at: u64,
}

// Create
public fun new(type_name: vector<u8>, clock: &Clock, ctx: &mut TxContext): Entity {
    Entity {
        id: object::new(ctx),
        `type`: type_name.to_string(),
        created_at: clock.timestamp_ms(),
    }
}

// Destroy — MUST delete UID explicitly
public fun destroy(entity: Entity) {
    let Entity { id, .. } = entity;
    id.delete();
}
```

---

## Dynamic Field — Component Key Convention

Use `ascii::String` keys with a `borrow_key()` pattern per component module:

```move
module game::health;

use std::ascii::String;
use sui::dynamic_field as df;

public struct Health has store, copy, drop {
    current: u64,
    max: u64,
}

const HEALTH_KEY: vector<u8> = b"health";

public fun add(entity: &mut Entity, health: Health) {
    df::add(entity.uid_mut(), HEALTH_KEY.to_ascii_string(), health);
}

public fun borrow(entity: &Entity): &Health {
    df::borrow(entity.uid(), HEALTH_KEY.to_ascii_string())
}

public fun borrow_mut(entity: &mut Entity): &mut Health {
    df::borrow_mut(entity.uid_mut(), HEALTH_KEY.to_ascii_string())
}

public fun has(entity: &Entity): bool {
    df::exists_(entity.uid(), HEALTH_KEY.to_ascii_string())
}

public fun remove(entity: &mut Entity): Health {
    df::remove(entity.uid_mut(), HEALTH_KEY.to_ascii_string())
}

// Receiver-syntax getters
public fun current(self: &Health): u64 { self.current }
public fun max(self: &Health): u64 { self.max }
public fun is_alive(self: &Health): bool { self.current > 0 }

public fun take_damage(self: &mut Health, amount: u64) {
    if (amount >= self.current) {
        self.current = 0;
    } else {
        self.current = self.current - amount;
    };
}
```

---

## UID Exposure — Security Model

```move
// SAFE: Read-only access to UID (anyone can read fields, not modify)
public fun uid(obj: &MyObject): &UID { &obj.id }

// DANGEROUS: Mutable UID lets ANYONE add/remove fields on your object
public fun uid_mut(obj: &mut MyObject): &mut UID { &mut obj.id }
```

**Best practice**: Engine exposes generic `add_component`/`borrow_component` functions that pass UID internally. External packages never get raw `&mut UID`.

---

## Currency Creation — Full Flow

```move
module my_game::gold;

use sui::coin;

/// One-Time Witness (must match module name, uppercase, only drop, no fields)
public struct GOLD has drop {}

fun init(witness: GOLD, ctx: &mut TxContext) {
    let (treasury_cap, metadata) = coin::create_currency(
        witness,          // OTW consumed
        9,                // decimals
        b"GOLD",          // symbol
        b"Game Gold",     // name
        b"In-game currency", // description
        option::none(),   // icon_url
        ctx,
    );

    // Freeze metadata (read-only for explorers)
    transfer::public_freeze_object(metadata);
    // Transfer treasury cap to admin
    transfer::public_transfer(treasury_cap, ctx.sender());
}
```

### Treasury Pattern — Balance Inside Structs

```move
public struct Treasury has key {
    id: UID,
    gold: Balance<GOLD>,     // embedded, NOT a separate object
}

public fun deposit(treasury: &mut Treasury, payment: Coin<GOLD>) {
    treasury.gold.join(coin::into_balance(payment));
}

public fun withdraw(treasury: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<GOLD> {
    coin::from_balance(treasury.gold.split(amount), ctx)
}

// Direct mint to player
public fun claim_reward(cap: &mut TreasuryCap<GOLD>, amount: u64, ctx: &mut TxContext) {
    coin::mint_and_transfer(cap, amount, ctx.sender(), ctx);
}
```

---

## Display — Full Setup

```move
module my_game::monsters;

use sui::display;
use sui::package;

public struct MONSTERS has drop {}

public struct Monster has key, store {
    id: UID,
    name: String,
    level: u64,
    image_url: String,
}

fun init(otw: MONSTERS, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let mut display = display::new<Monster>(&publisher, ctx);
    display.add(b"name".to_string(), b"{name}".to_string());
    display.add(b"description".to_string(), b"Level {level} monster".to_string());
    display.add(b"image_url".to_string(), b"{image_url}".to_string());
    display.add(b"project_url".to_string(), b"https://mygame.com".to_string());
    display.update_version();  // commit — makes active

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(display, ctx.sender());
}
```

Template syntax: `{field_name}` interpolates struct fields.
Standard fields: `name`, `description`, `image_url`, `project_url`, `link`, `creator`, `thumbnail_url`.

---

## Randomness — Security Rules

> **CRITICAL**: Randomness-dependent functions are vulnerable to gas manipulation attacks.

### Rules

1. **Must consume in `entry` function** — don't expose `RandomGenerator` through `public`
2. **Don't make transfers conditional on random outcome** — always transfer something
3. **Use `entry` (not `public entry`)** to prevent composability attacks
4. **Random singleton lives at address `0x8`**

### Full Pattern

```move
entry fun attack(
    attacker: &mut Entity,
    defender: &mut Entity,
    r: &Random,          // singleton at 0x8
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let mut gen = random::new_generator(r, ctx);
    let roll = gen.generate_u64_in_range(1, 20); // d20
    let damage = if (roll >= 10) {
        gen.generate_u64_in_range(5, 15)
    } else {
        0
    };
    // ALWAYS apply result — don't skip transfer based on roll
    apply_damage(defender, damage);
    event::emit(AttackEvent { roll, damage });
}
```

---

## Clock — Usage & Testing

```move
// Clock is ALWAYS passed as &Clock (immutable). &mut Clock is REJECTED at runtime.
// Clock address is always 0x6.
// Resolution: ~2-3 seconds (per consensus commit). Don't use for sub-second timing.

entry fun attack(entity: &mut Entity, clock: &Clock, ctx: &mut TxContext) {
    let now = clock.timestamp_ms();
    let cooldown = borrow_cooldown(entity);
    assert!(now >= cooldown.ready_at, ECooldownActive);
}
```

### epoch_timestamp_ms vs Clock

| Feature | `ctx.epoch_timestamp_ms()` | `clock.timestamp_ms()` |
|---------|--------------------------|----------------------|
| Precision | Once per epoch (~24h) | Each consensus commit (~2-3s) |
| Use for | Epoch-based logic (staking) | Cooldowns, timers |
| Gas cost | Free | Slightly higher |

### Testing Boilerplate

```move
#[test]
fun test_cooldown() {
    let mut clock = clock::create_for_testing(ctx);
    clock.set_for_testing(1000);           // set to 1000ms
    // ... test at 1000ms ...
    clock.increment_for_testing(5000);     // advance by 5s
    // ... test at 6000ms ...
    clock.destroy_for_testing();
}

#[test]
fun test_random() {
    let mut ctx = tx_context::dummy();
    random::create_for_testing(&mut ctx);
    // retrieve from test scenario, then:
    let mut gen = random::new_generator(&random_obj, &mut ctx);
    let val = gen.generate_u64_in_range(1, 6);
    assert!(val >= 1 && val <= 6);
}
```

---

## Version Guard — Full Migration Flow

```move
const VERSION: u8 = 2;  // bumped from 1
const EVersionMismatch: u64 = 0;

public struct SharedState has key {
    id: UID,
    version: u8,
}

// Every public function checks version
public fun mutate(state: &mut SharedState) {
    assert!(state.version == VERSION, EVersionMismatch);
    // ... actual logic
}

// Migration: admin bumps version after upgrade
public fun migrate(state: &mut SharedState, cap: &AdminCap) {
    assert!(state.version == VERSION - 1, EVersionMismatch);
    state.version = VERSION;
    // ... apply data migrations (e.g., swap ConfigV1 → ConfigV2)
}
```

### Config Anchoring — Dynamic Field Config

```move
public struct Config has key {
    id: UID,
    version: u16,
}

public struct ConfigV1 has store {
    max_health: u64,
    base_damage: u64,
    cooldown_ms: u64,
}

public fun config_v1(config: &Config): &ConfigV1 {
    assert!(config.version == 1, EVersionMismatch);
    df::borrow(&config.id, ConfigV1Key())
}

// On upgrade to v2:
// 1. Define ConfigV2 with new fields
// 2. migrate() removes ConfigV1, adds ConfigV2
// 3. Config struct itself NEVER changes (only id + version)
```

---

## Transfer — Same Module vs Cross-Module

```move
// WITHIN defining module — use non-public variants (works without `store`)
public struct Entity has key { id: UID }

fun init(ctx: &mut TxContext) {
    transfer::transfer(Entity { id: object::new(ctx) }, ctx.sender()); // OK
}

// FROM ANOTHER module — use public variants (REQUIRES `store`)
public struct Item has key, store { id: UID }

public fun give_item(item: Item, to: address) {
    transfer::public_transfer(item, to); // OK: Item has store
}

// Receiving objects sent to a parent object
public fun receive_item(parent: &mut UID, incoming: Receiving<Item>): Item {
    transfer::public_receive(parent, incoming) // Item has key+store
}
```

---

## Collection Edge Cases

### VecSet
- **Aborts on duplicate** `insert` — check `contains` first if unsure
- **Aborts if not found** on `remove` — check `contains` first
- **Cannot compare** two VecSets — insertion order differs

### VecMap
- **Unique keys** — `insert` aborts if key exists
- `remove` returns both `(key, value)`
- `into_keys_values()` consumes the map

### PriorityQueue
- Despite `pop_max` name, it's a **max-heap** — highest priority number pops first
- Values need `drop` ability

### Table / Bag
- Have internal `UID` — cannot `copy` or `drop`, must `destroy_empty()`
- `Bag` tracks size — aborting on non-empty destroy prevents orphaned fields

### LinkedTable
- `push_front` / `push_back` for ordered insertion
- Traversal via `front()` → `next(key)` chain
- `pop_front()` / `pop_back()` for queue/stack behavior

---

## Loop Macros (Move 2024)

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

---

## Enums & Match (Move 2024)

```move
public enum GameState has store, copy, drop {
    Waiting,
    InProgress { round: u64 },
    Finished { winner: address },
}

public fun describe(state: &GameState): String {
    match (state) {
        GameState::Waiting => b"waiting".to_string(),
        GameState::InProgress { round } => b"round".to_string(),
        GameState::Finished { winner } => b"finished".to_string(),
    }
}
```

---

## Error Handling — Guard Functions Pattern

```move
const EAttackerMissingHealth: u64 = 0;
const EDefenderMissingHealth: u64 = 1;
const EAttackerDead: u64 = 2;
const EDefenderDead: u64 = 3;
const ECooldownActive: u64 = 4;

// Public checks return bool — callers choose their error handling
public fun is_alive(entity: &Entity): bool {
    health::borrow(entity).current() > 0
}

// Reusable guard (private or public(package))
fun assert_entity_ready(entity: &Entity, clock: &Clock) {
    assert!(entity.is_alive(), EEntityDead);
    assert!(entity.cooldown_ready(clock), ECooldownActive);
}

// System entry points call guards
public fun attack(
    attacker: &mut Entity,
    defender: &mut Entity,
    clock: &Clock,
) {
    assert!(health::has(attacker), EAttackerMissingHealth);
    assert!(health::has(defender), EDefenderMissingHealth);
    assert_entity_ready(attacker, clock);
    assert_entity_ready(defender, clock);
    // ... combat logic
}
```

---

## Testing Conventions

```move
#[test_only]
module my_package::my_module_tests;

// ✅ No test_ prefix (module name says it's tests)
#[test]
fun entity_spawns_with_correct_health() { ... }

// ✅ Combined annotations
#[test, expected_failure(abort_code = my_module::ENotAuthorized)]
fun unauthorized_access_fails() {
    let mut test = ts::begin(@0);
    my_module::restricted_action(test.ctx());
    abort  // clearly: test should have aborted before this
}

// ✅ Use dummy context when full scenario isn't needed
let ctx = &mut tx_context::dummy();
create_item(ctx).destroy();

// ✅ assert_eq! prints both values on failure
use std::unit_test::assert_eq;
assert_eq!(health, 100);

// ✅ Destroy any value in tests
use sui::test_utils;
test_utils::destroy(some_object);
```

---

## Import Conventions

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

## Dynamic Field Key — Positional Struct (Modern)

```move
// ✅ Modern: positional struct
public struct HealthKey() has copy, drop, store;

// ❌ Legacy: empty braces
public struct HealthKey has copy, drop, store {}
```
