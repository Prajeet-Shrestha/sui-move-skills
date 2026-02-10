# Upgradeability

> Source: [Move Book — Upgradeability Practices](https://move-book.com/guides/upgradeability-practices)

## Compatibility Rules

An upgrade must not break **public compatibility** with the previous version.

### What CAN'T change (locked forever once published)

| Element | Rule |
|---------|------|
| Modules | Cannot be removed from a package |
| `public struct` | Cannot be removed, renamed, or have fields changed |
| `public fun` | Cannot be removed; signature cannot change |
| Struct abilities | Cannot be removed from a published struct |

### What CAN change

| Element | Rule |
|---------|------|
| `public fun` implementation | Body can change freely |
| `public(package) fun` | Can be removed, renamed, signature changed |
| `entry fun` (non-public) | Can be removed, renamed, signature changed |
| `fun` (private) | Fully changeable |
| Dependencies | Can change (if not used in public signatures) |
| New modules | Can be added |
| New functions | Can be added to existing modules |
| New structs | Can be added to existing modules |

### Design Implications

```move
// ❌ AVOID: public struct you might need to change
public struct GameState has key {
    id: UID,
    score: u64,           // can NEVER remove or rename this field
    multiplier: u64,      // locked forever
}

// ✅ PREFER: minimal anchor + dynamic config
public struct GameState has key {
    id: UID,
    version: u16,         // version field for guard
}
// Actual config stored as dynamic field — can change shape on upgrade
```

---

## Version Guard Pattern

Every shared object should have a version field. Every entry point should assert the version.

```move
const VERSION: u8 = 1;
const EVersionMismatch: u64 = 0;

public struct SharedState has key {
    id: UID,
    version: u8,
}

// Guard: every public function checks version
public fun mutate(state: &mut SharedState) {
    assert!(state.version == VERSION, EVersionMismatch);
    // ... actual logic
}

// Migration: admin bumps version after upgrade
public fun migrate(state: &mut SharedState, cap: &AdminCap) {
    assert!(state.version == VERSION - 1, EVersionMismatch);
    state.version = VERSION;
    // ... apply data migrations
}
```

### How It Works

1. Publish v1 with `VERSION = 1`, all functions assert `version == 1`
2. Upgrade to v2: set `VERSION = 2`, old functions now abort on existing objects
3. Call `migrate()` to bump object version from 1 → 2
4. New functions now work, old code is effectively dead

---

## Config Anchoring Pattern

Store actual configuration as versioned dynamic fields, keeping the anchor struct minimal and stable.

```move
public struct Config has key {
    id: UID,
    version: u16,
}

/// v1 config — stored as dynamic field on Config
public struct ConfigV1 has store {
    max_health: u64,
    base_damage: u64,
    cooldown_ms: u64,
}

// Accessor
public fun config_v1(config: &Config): &ConfigV1 {
    assert!(config.version == 1, EVersionMismatch);
    df::borrow(&config.id, ConfigV1Key())
}

// On upgrade to v2:
// 1. Define ConfigV2 with new fields
// 2. migrate() removes ConfigV1, adds ConfigV2
// 3. Update accessor to config_v2()
// 4. Config struct itself never changes
```

**Why this works**: `Config` only has `id` and `version` — it never needs to change its struct definition. All actual data lives in dynamic fields that can be swapped on upgrade.

---

## Upgrade Policies

| Policy | What's Allowed | When to Use |
|--------|---------------|-------------|
| Compatible (default) | Any compatible change | Active development |
| Additive only | Only add new code, no changes | Stabilized APIs |
| Dependency-only | Only update deps | Frozen logic, dep patches only |
| Immutable | Nothing (cap destroyed) | Fully audited, permanent |

```move
// Progressively restrict (one-way, irreversible)
cap.only_additive_upgrades();   // compatible → additive
cap.only_dep_upgrades();        // → dependency-only
cap.make_immutable();           // destroyed, no more upgrades

// In practice: keep UpgradeCap in a multisig or governance object
```

---

## Engine-Specific Guidance

### Rule 1: Keep public structs minimal

```move
// Entity struct — keep fields to absolute minimum
public struct Entity has key {
    id: UID,
    `type`: String,         // never changes meaning
    created_at: u64,        // never changes meaning
}
// All game data goes in dynamic fields (components)
```

### Rule 2: Prefer `public(package)` over `public` for internal APIs

```move
// Only the engine package calls this — use package visibility
public(package) fun uid_mut(entity: &mut Entity): &mut UID { ... }

// External packages call this — must be public
public fun borrow_component<T>(entity: &Entity, key: String): &T { ... }
```

### Rule 3: Version your registries

```move
// Config registries should be versioned
public struct HealthConfig has key {
    id: UID,
    version: u8,
    // actual values in dynamic fields
}
```
