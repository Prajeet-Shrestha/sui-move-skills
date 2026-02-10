/// Template: System Events Module
/// Defines event structs and emit functions for off-chain indexing.
module combat_sys::events;

use std::ascii::String;
use sui::event;

// ─── Event Structs (must have copy, drop) ───

public struct AttackEvent has copy, drop {
    attacker_id: ID,
    defender_id: ID,
    damage: u64,
    timestamp: u64,
}

public struct EntityCreatedEvent has copy, drop {
    entity_id: ID,
    entity_type: String,
    timestamp: u64,
}

// ─── Emit Functions (package-visible) ───────

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

public(package) fun emit_entity_created(
    entity_id: ID,
    entity_type: String,
    timestamp: u64,
) {
    event::emit(EntityCreatedEvent {
        entity_id,
        entity_type,
        timestamp,
    });
}
