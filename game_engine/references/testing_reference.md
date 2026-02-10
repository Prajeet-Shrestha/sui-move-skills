# Testing — Best Practices

## Test File Location

```
packages/systems/combat_sys/
└── tests/
    └── combat_tests.move
```

## Test Module Pattern

```move
#[test_only]
module combat_sys::combat_tests;

use sui::test_scenario::{Self as ts, Scenario};
use sui::clock::{Self, Clock};
use std::ascii;

use entity::entity::{Self, Entity};
use health::health;
use position::position;

// ─── Constants ──────────────────────────
const PLAYER1: address = @0x1;
const PLAYER2: address = @0x2;

// ─── Setup Helpers ──────────────────────

fun create_player(scenario: &mut Scenario, clock: &Clock): Entity {
    let mut entity = entity::new(
        ascii::string(b"player"),
        clock,
        ts::ctx(scenario),
    );
    health::add_component(health::new(100), &mut entity);
    position::add_component(position::new(0, 0), &mut entity);
    entity
}

// ─── Tests ──────────────────────────────

#[test]
fun test_attack_reduces_health() {
    let mut scenario = ts::begin(PLAYER1);
    let clock = clock::create_for_testing(ts::ctx(&mut scenario));

    // Create entities
    let attacker = create_player(&mut scenario, &clock);
    entity::share(attacker);
    let defender = create_player(&mut scenario, &clock);
    entity::share(defender);

    // Perform action
    ts::next_tx(&mut scenario, PLAYER1);
    {
        let mut attacker = ts::take_shared<Entity>(&scenario);
        let mut defender = ts::take_shared<Entity>(&scenario);

        combat_sys::entry::attack(&mut attacker, &mut defender, &clock);

        // Verify
        let health = health::borrow(&defender);
        assert!(health.current() < 100, 0);

        ts::return_shared(attacker);
        ts::return_shared(defender);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}
```

## Key Test Utilities

### test_scenario

```move
let mut scenario = ts::begin(PLAYER1);       // Start scenario with address
ts::next_tx(&mut scenario, PLAYER1);          // Advance to next transaction
let obj = ts::take_shared<Entity>(&scenario); // Take shared object
ts::return_shared(obj);                        // Return it when done
ts::end(scenario);                             // Cleanup
```

### Clock

```move
let clock = clock::create_for_testing(ts::ctx(&mut scenario));
clock::set_for_testing(&mut clock, 1000);         // Set timestamp (ms)
clock::increment_for_testing(&mut clock, 5000);   // Advance time
clock::destroy_for_testing(clock);                 // Cleanup
```

### Test-Only Helpers in Components

Components should provide test constructors that bypass config/auth dependencies:

```move
// In component module:
#[test_only]
public fun new_for_testing(): Health {
    Health { current: 100, max: 100 }
}

#[test_only]
public fun set_current_for_testing(self: &mut Health, value: u64) {
    self.current = value;
}
```

Config modules should expose `init_for_testing`:

```move
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
```

## Running Tests

```bash
# Test a specific package
cd packages/systems/combat_sys && sui move test

# Verbose output
sui move test -v

# Specific test function
sui move test test_attack_reduces_health
```

## Checklist

- [ ] Create `tests/` directory in package
- [ ] Set up test constants (PLAYER addresses)
- [ ] Write setup helpers (`create_player`, etc.)
- [ ] Test happy paths for each entry function
- [ ] Test edge cases and error assertions
- [ ] Test multi-entity interactions
- [ ] Use `clock` for time-dependent logic
