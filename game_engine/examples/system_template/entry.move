/// Template: System Entry Module
/// The "API layer" of a system — validates input, orchestrates logic, emits events.
module combat_sys::entry;

use std::ascii;
use sui::clock::Clock;
use entity::entity::{Self, Entity};

// System's own modules
use combat_sys::helpers;
use combat_sys::events;

// Components this system operates on
// use health::health;
// use position::position;

// ─── Error Constants ────────────────────────

const EAttackerDead: u64 = 0;
const ETargetOutOfRange: u64 = 1;

// ─── Entry Functions ────────────────────────

/// Attack another entity
public fun attack(
    attacker: &mut Entity,
    defender: &mut Entity,
    clock: &Clock,
) {
    // 1. Validate preconditions
    // let atk_health = health::borrow(attacker);
    // assert!(atk_health.is_alive(), EAttackerDead);

    // 2. Compute (delegate to helpers for complex logic)
    // let damage = helpers::calculate_damage(attacker, defender);

    // 3. Mutate components
    // let def_health = health::borrow_mut(defender);
    // health::take_damage(def_health, damage);

    // 4. Emit event (always at the end)
    events::emit_attack_event(
        object::id(attacker),
        object::id(defender),
        0, // damage
        clock.timestamp_ms(),
    );
}

/// Create a new player entity with standard components
public fun create_player(
    name: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let mut entity = entity::new(ascii::string(b"player"), clock, ctx);

    // Attach components
    // health::add_component(health::new(100), &mut entity);
    // position::add_component(position::new(0, 0), &mut entity);

    entity::share(entity);
}
