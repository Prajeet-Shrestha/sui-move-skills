/// Template: Component with Config Registry
/// Demonstrates a component + shared Registry for tunable game parameters.
module my_game::stamina_config;

use std::ascii::{Self, String};
use sui::dynamic_field;

// ─── Registry (Shared Config) ───────────────

/// Created once at package publish. Holds tunable game parameters.
public struct Registry has key {
    id: UID,
    max_stamina: u64,
    regen_per_minute: u64,
    // Per-activity costs stored as dynamic fields
}

/// Per-activity stamina cost data
public struct ActivityCost has drop, store {
    name: String,
    cost: u64,
}

// ─── Init ───────────────────────────────────

fun init(ctx: &mut TxContext) {
    transfer::share_object(Registry {
        id: object::new(ctx),
        max_stamina: 100,
        regen_per_minute: 1,
    });
}

// ─── Setters ────────────────────────────────

entry fun set_max_stamina(registry: &mut Registry, value: u64) {
    registry.max_stamina = value;
}

entry fun set_regen_rate(registry: &mut Registry, value: u64) {
    registry.regen_per_minute = value;
}

/// Set cost for a specific activity via dynamic fields
entry fun set_activity_cost(
    registry: &mut Registry,
    name: String,
    cost: u64,
) {
    let data = ActivityCost { name, cost };
    if (!dynamic_field::exists_(&registry.id, name)) {
        dynamic_field::add(&mut registry.id, name, data);
    } else {
        let existing: &mut ActivityCost = dynamic_field::borrow_mut(&mut registry.id, name);
        existing.cost = cost;
    };
}

// ─── Getters ────────────────────────────────

public fun max_stamina(registry: &Registry): u64 {
    registry.max_stamina
}

public fun regen_per_minute(registry: &Registry): u64 {
    registry.regen_per_minute
}

public fun activity_cost(registry: &Registry, name: String): u64 {
    let data: &ActivityCost = dynamic_field::borrow(&registry.id, name);
    data.cost
}

// ─── Test Helper ────────────────────────────

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
