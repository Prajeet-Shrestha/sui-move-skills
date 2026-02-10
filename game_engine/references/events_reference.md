# Events — Best Practices

Events are emitted by systems and consumed by off-chain indexers and clients. They are the bridge between on-chain game state and off-chain UIs.

## Event Rules

1. Events must have `copy, drop` abilities (required by `sui::event::emit()`)
2. Events are **transient** — they are NOT stored on-chain
3. Use only primitive types: `ID`, `u64`, `u128`, `String`, `bool`, `address`, `vector<T>`

## Event Module Pattern

```move
module combat_sys::events;

use std::ascii::String;
use sui::event;

// ─── Event Structs ──────────────────────

public struct AttackEvent has copy, drop {
    attacker_id: ID,
    defender_id: ID,
    damage: u64,
    timestamp: u64,
}

// ─── Emit Functions ─────────────────────

/// Package-visible: called from entry.move
public(package) fun emit_attack_event(
    attacker_id: ID,
    defender_id: ID,
    damage: u64,
    timestamp: u64,
) {
    event::emit(AttackEvent {
        attacker_id,
        defender_id,
        damage,
        timestamp,
    });
}
```

## Structured Log Events

For complex systems (battles, raids), use nested structs for detailed logging:

```move
public struct UnitSnapshot has copy, drop {
    unit_type: String,
    count: u64,
    total_health: u128,
}

public struct BattleEvent has copy, drop {
    total_rounds: u64,
    winner: u8,            // 1 = attacker, 2 = defender, 3 = draw
    attackers: vector<UnitSnapshot>,
    defenders: vector<UnitSnapshot>,
}
```

## Best Practices

| Practice | Why |
|----------|-----|
| Always include entity `ID`s | Enables indexers to track entities |
| Always include `timestamp: u64` | Enables off-chain ordering and time queries |
| Use `public(package)` for emit functions | Only the system's own entry.move should emit |
| Emit at the END of entry functions | Ensures the event reflects the final state |
| Include before/after values when useful | Enables change tracking without full state reads |

## Checklist

- [ ] Create `events.move` in system's `sources/` directory
- [ ] Define event structs with `has copy, drop`
- [ ] Include identifying fields (entity IDs, player IDs)
- [ ] Include `timestamp: u64`
- [ ] Create `public(package)` emit functions
- [ ] Call emit functions at the end of entry functions
