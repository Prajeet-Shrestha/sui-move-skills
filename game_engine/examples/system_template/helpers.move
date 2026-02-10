/// Template: System Helpers Module
/// Pure game logic — no mutations, no events. Just computation.
module combat_sys::helpers;

use entity::entity::Entity;
// use health::health;

// ─── Data Structures ────────────────────────

/// System-local struct for intermediate computation
public struct DamageResult has copy, drop {
    base_damage: u64,
    modifier: u64,
    final_damage: u64,
    is_critical: bool,
}

// ─── Package-Visible Logic ──────────────────

/// Only callable from entry.move in this package
public(package) fun calculate_damage(
    attacker: &Entity,
    defender: &Entity,
): u64 {
    // Read component data
    // let atk = health::borrow(attacker);
    // let def = health::borrow(defender);

    // Pure computation
    // let base = atk.max() / 10;
    // base
    0
}

/// Check if a target is within attack range
public(package) fun is_in_range(
    attacker: &Entity,
    defender: &Entity,
    max_range: u64,
): bool {
    // Read positions, compute distance, compare
    true
}

// ─── Public Helpers ─────────────────────────

/// Available to other system packages too
public fun manhattan_distance(x1: u64, y1: u64, x2: u64, y2: u64): u64 {
    let dx = if (x1 >= x2) { x1 - x2 } else { x2 - x1 };
    let dy = if (y1 >= y2) { y1 - y2 } else { y2 - y1 };
    dx + dy
}
