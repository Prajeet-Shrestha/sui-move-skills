/// Template: Simple Component
/// A minimal component demonstrating the standard pattern.
/// Copy this file and replace Health with your component.
module my_game::health;

use std::ascii::{Self, String};
use entity::entity::{Entity};

// ─── Struct ─────────────────────────────────

/// store, copy, drop — for simple value types
/// store, drop       — if fields include String or Url
/// key, store        — if you need nested dynamic fields (e.g. inventory)
public struct Health has store, copy, drop {
    current: u64,
    max: u64,
}

// ─── Key ────────────────────────────────────

/// Unique key for this component. Used as the dynamic field key on entities.
public fun borrow_key(): vector<u8> {
    b"health"
}

// ─── Constructor ────────────────────────────

public fun new(max: u64): Health {
    Health { current: max, max }
}

// ─── Entity Integration ─────────────────────

public fun add_component(health: Health, entity: &mut Entity) {
    entity.add_component(ascii::string(borrow_key()), health);
}

public fun borrow(entity: &Entity): &Health {
    entity.borrow_component<Health>(ascii::string(borrow_key()))
}

public fun borrow_mut(entity: &mut Entity): &mut Health {
    entity.borrow_mut_component<Health>(ascii::string(borrow_key()))
}

// ─── Getters ────────────────────────────────

public fun current(self: &Health): u64 { self.current }
public fun max(self: &Health): u64 { self.max }
public fun is_alive(self: &Health): bool { self.current > 0 }

// ─── Setters ────────────────────────────────

public fun take_damage(self: &mut Health, amount: u64) {
    if (amount >= self.current) { self.current = 0; }
    else { self.current = self.current - amount; };
}

public fun heal(self: &mut Health, amount: u64) {
    self.current = std::u64::min(self.current + amount, self.max);
}

public fun set_max(self: &mut Health, new_max: u64) {
    self.max = new_max;
    if (self.current > self.max) { self.current = self.max; };
}

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Health {
    Health { current: 100, max: 100 }
}

#[test_only]
public fun set_current_for_testing(self: &mut Health, value: u64) {
    self.current = value;
}
