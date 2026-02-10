# Project Setup — Best Practices

## Move.toml Templates

### Entity Package

```toml
[package]
name = "entity"
edition = "2024.beta"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }

[addresses]
entity = "0x0"
```

### Component Package

```toml
[package]
name = "health"
edition = "2024.beta"

[dependencies]
entity = { local = "../../entity" }

[addresses]
health = "0x0"
```

### System Package

```toml
[package]
name = "combat_sys"
edition = "2024.beta"

[dependencies]
entity = { local = "../../entity" }
health = { local = "../../components/health" }
position = { local = "../../components/position" }

[addresses]
combat_sys = "0x0"
```

## Directory Layout

```bash
# New component
mkdir -p packages/components/health/{sources,tests}

# New system
mkdir -p packages/systems/combat_sys/{sources,tests}
```

### Component files

```
packages/components/health/
├── Move.toml
├── sources/
│   ├── health.move           # Struct, key, constructors, getters/setters
│   └── health_config.move    # Registry config (optional)
└── tests/
    └── health_tests.move
```

### System files

```
packages/systems/combat_sys/
├── Move.toml
├── sources/
│   ├── entry.move            # Transaction entry points
│   ├── helpers.move           # Pure game logic
│   ├── events.move            # Event definitions
│   └── version.move           # Version placeholder
└── tests/
    └── combat_tests.move
```

## Dependency Rules

```
Entity ← Components ← Systems
          ↑                ↑
       Configs          Configs
```

1. **Entity** is standalone (depends only on Sui framework)
2. **Components** depend on `entity`
3. **Systems** depend on `entity` + all components they operate on
4. **No circular deps** — components cannot depend on systems
5. **Systems cannot depend on other systems** — compose at the game layer if needed
6. **Smart components** may depend on other components (e.g., `level` depends on `xp`)

## Edition

Use `edition = "2024.beta"` for modern Sui Move features:
- Receiver syntax: `entity.add_component(...)` instead of `add_component(&mut entity, ...)`
- Method syntax on references
- Improved type inference

## Build & Test

```bash
# Build a package
cd packages/systems/combat_sys && sui move build

# Test a package
cd packages/systems/combat_sys && sui move test

# Test with verbose output
sui move test -v
```

## Common Sui Imports (automatic via framework)

```move
use sui::object;          // UID, ID
use sui::dynamic_field;   // Dynamic field operations
use sui::transfer;        // transfer, share_object
use sui::clock::Clock;    // Timestamps
use sui::event;           // Event emission
use sui::vec_map;         // VecMap<K, V>
use sui::bag;             // Bag (heterogeneous collection)
use sui::random;          // On-chain randomness
use std::ascii;           // ASCII strings
use std::vector;          // Vector operations
```
