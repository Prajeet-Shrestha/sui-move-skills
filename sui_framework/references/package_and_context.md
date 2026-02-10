# Package & Context Modules

> Covers `sui::package`, `sui::tx_context`

## `sui::tx_context` — Transaction Context

Provides information about the currently executing transaction. Passed to entry functions automatically.

### The TxContext Struct

```move
public struct TxContext has drop {
    sender: address,           // who signed the transaction
    tx_hash: vector<u8>,       // transaction digest
    epoch: u64,                // current epoch number
    epoch_timestamp_ms: u64,   // epoch start time (less precise than Clock)
    ids_created: u64,          // counter for UID generation
}
```

### API

```move
// Identity
ctx.sender(): address                   // transaction signer
ctx.sponsor(): address                  // gas sponsor (if sponsored)

// Time (epoch-level granularity — prefer Clock for precise timing)
ctx.epoch(): u64                        // current epoch number
ctx.epoch_timestamp_ms(): u64           // epoch start timestamp

// Transaction info
ctx.digest(): &vector<u8>              // transaction hash

// Object creation
ctx.fresh_object_address(): address     // generate unique address for new objects
```

### Common Patterns

```move
// Check if sender is admin
assert!(ctx.sender() == ADMIN_ADDRESS, ENotAdmin);

// Alternative: use Capability pattern instead of hardcoded address
public fun admin_action(cap: &AdminCap, ...) {
    // cap ownership proves authorization — no address checks needed
}
```

### `epoch_timestamp_ms` vs `Clock`

| Feature | `ctx.epoch_timestamp_ms()` | `clock.timestamp_ms()` |
|---------|--------------------------|----------------------|
| Precision | Updated once per epoch (~24h) | Updated each consensus commit (~2-3s) |
| Requires parameter | No (ctx always available) | Yes (`&Clock`) |
| Use for | Epoch-based logic | Cooldowns, timers |
| Gas cost | Free (already in ctx) | Slightly higher (shared object read) |

**Rule**: Use `Clock` for game timers. Use `ctx.epoch()` only for epoch-level mechanics (staking rewards, seasonal resets).

---

## `sui::package` — Package Identity & Upgrades

Controls package publishing identity, upgrade permissions, and version management.

### Key Types

```move
/// Proves the publisher of a package. Created by consuming OTW in `init`.
public struct Publisher has key, store {
    id: UID,
    package: ascii::String,      // package address
    module_name: ascii::String,  // module name
}

/// Controls upgrade permissions for a package.
public struct UpgradeCap has key, store {
    id: UID,
    package: ID,       // package being controlled
    version: u64,      // current version
    policy: u8,        // upgrade policy level
}

/// One-time use ticket to perform an upgrade.
public struct UpgradeTicket { ... }

/// Receipt confirming an upgrade was committed.
public struct UpgradeReceipt { ... }
```

### Publisher — Package Identity

```move
use sui::package;

// Claim publisher in init (consumes OTW)
fun init(otw: MY_MODULE, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);
    // publisher proves this code published the package

    // Check if a type belongs to this publisher
    publisher.from_package<MyType>(): bool   // true if MyType is from this package
    publisher.from_module<MyType>(): bool    // true if MyType is from this module

    // Get publisher info
    publisher.published_package(): &ascii::String
    publisher.published_module(): &ascii::String

    transfer::public_transfer(publisher, ctx.sender());
}
```

**Engine use**: Publisher is required to create `Display` objects. Claim it in `init` and keep it.

### UpgradeCap — Version Control

The `UpgradeCap` is automatically created when a package is published. It controls what kinds of upgrades are allowed.

#### Upgrade Policies (from most to least permissive)

| Policy | Value | Allows |
|--------|-------|--------|
| Compatible | `0` | Any compatible change (default) |
| Additive | `128` | Only add new functions/types, no changes to existing |
| Dependency-only | `192` | Only update dependencies |
| Immutable | N/A | No upgrades (cap destroyed) |

```move
// Restrict upgrade policy (one-way, can only make MORE restrictive)
cap.only_additive_upgrades()      // compatible → additive
cap.only_dep_upgrades()           // → dependency-only
cap.make_immutable()              // destroys cap, no more upgrades ever

// Query
cap.version(): u64                // current version
cap.upgrade_policy(): u8          // current policy
cap.upgrade_package(): ID         // package ID
```

#### Performing an Upgrade

```move
// 1. Authorize (gets a ticket)
let ticket = cap.authorize_upgrade(policy, digest);

// 2. Perform upgrade (system operation)
// ... upload new bytecode ...

// 3. Commit (consumes receipt)
cap.commit_upgrade(receipt);
```

### Engine Pattern: Version Guards

```move
const CURRENT_VERSION: u64 = 1;

public struct GameConfig has key {
    id: UID,
    version: u64,
    // ... config fields
}

public fun assert_version(config: &GameConfig) {
    assert!(config.version == CURRENT_VERSION, EWrongVersion);
}

// Every entry function checks version
public entry fun play(config: &GameConfig, ...) {
    assert_version(config);
    // ... game logic
}

// Migration function for upgrades
public entry fun migrate(config: &mut GameConfig, cap: &UpgradeCap) {
    assert!(config.version == CURRENT_VERSION - 1, ENotMigratable);
    config.version = CURRENT_VERSION;
    // ... apply data migrations
}
```

### Common Init Pattern

```move
module my_game::my_module {
    public struct MY_MODULE has drop {} // OTW

    fun init(otw: MY_MODULE, ctx: &mut TxContext) {
        // 1. Claim publisher (for Display)
        let publisher = package::claim(otw, ctx);

        // 2. Create shared game config
        let config = GameConfig {
            id: object::new(ctx),
            version: 1,
        };
        transfer::share_object(config);

        // 3. Keep publisher for admin
        transfer::public_transfer(publisher, ctx.sender());

        // Note: UpgradeCap is created automatically by Sui
        // and transferred to the publisher address
    }
}
```
