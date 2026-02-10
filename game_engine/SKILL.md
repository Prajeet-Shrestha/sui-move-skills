---
name: ECS Game Engine Principles
description: Build on-chain games on Sui using the Entity-Component-System architecture. Covers entity creation, component design, system implementation, config registries, events, and testing.
---

# ECS Game Engine Principles

Principles and patterns for building a **reusable on-chain ECS game engine on Sui Move**. Follow these when designing engine primitives, APIs, and extension points. The engine you build will be consumed by other AI agents and developers to create games.

## The Two-Layer Model

```
┌─────────────────────────────────────────────────┐
│  GAME LAYER (built by other AIs/developers)     │
│  Systems, components, configs for a specific    │
│  game — combat, economy, quests, etc.           │
└──────────────────────┬──────────────────────────┘
                       │ uses
┌──────────────────────▼──────────────────────────┐
│  ENGINE LAYER (built by you)                    │
│  Entity primitive, component attachment API,    │
│  dynamic field conventions, shared patterns     │
└─────────────────────────────────────────────────┘
```

**Your job**: Build the engine layer so well that game-layer code is obvious and repetitive. If someone has to think hard about *how* to attach a component or structure a system, the engine design has failed.

## Core Architecture: ECS on Sui

| Concept | Sui Implementation | Owned By |
|---------|-------------------|----------|
| Entity | Sui object (`has key`) with a `UID` | Engine |
| Component | Data struct (`has store`) as dynamic field | Game layer |
| Component Key | `ascii::String` — the dynamic field key | Game layer |
| System | Stateless Move module | Game layer |
| Config Registry | Shared object for game parameters | Game layer |
| Event | `copy + drop` struct emitted via `sui::event` | Game layer |

The engine owns the Entity primitive and the conventions. The game layer follows the conventions to build components, systems, and configs.

## Engine Design Principles

### 1. Entity Is a Dumb Container
The entity struct should hold **only** an ID, a type string, and a creation timestamp. Never add game-specific fields. All game data flows through components (dynamic fields).

```move
public struct Entity has key {
    id: UID,
    `type`: String,
    created_at: u64,
}
```

**Why:** This keeps the engine generic. Any game can use the same Entity regardless of what components it needs.

### 2. Dynamic Fields for Composition
Components attach as dynamic fields keyed by `ascii::String`. This gives:
- **Lazy loading** — only accessed components cost gas
- **Unlimited composition** — any number of components per entity
- **No schema migrations** — adding a new component type doesn't change Entity

### 3. One Pattern, Every Time
The engine succeeds when every component module looks the same:
```
struct → key → constructor → add → borrow → borrow_mut → getters → setters → test helpers
```
If a game developer or AI can predict the API shape of a new component without reading its code, the engine conventions are working.

### 4. Systems Are Pure Functions
Systems should be stateless modules. No structs stored in the module, no global state. They take entities in, read/write components, and return. This makes systems independently deployable and upgradeable.

### 5. Separate Entry from Logic
Every system package splits into:
- `entry.move` — Transaction API: validates, orchestrates, emits events
- `helpers.move` — Pure computation: reusable, testable, no side effects
- `events.move` — Event definitions: the off-chain communication contract

This split makes systems testable and their logic reusable across different entry points.

### 6. Config Over Constants
Game parameters belong in shared `Registry` objects, not `const` values. This enables:
- Runtime tuning without package upgrades
- Different parameter sets per deployment
- Admin-controlled game economy

### 7. Design for AI Consumption
Other AIs will use this engine to build games. Make their job easy:
- **Consistent naming**: `borrow_key()`, `add_component()`, `borrow()`, `borrow_mut()`
- **Predictable signatures**: constructors return the struct, add functions take entity + component
- **Self-documenting keys**: `b"health"`, `b"position"`, `b"inventory"` — not abbreviations
- **Test helpers for everything**: `new_for_testing()`, `init_for_testing()` so tests don't need complex setup
- **Checklists in templates**: a game-building AI should just follow the checklist

## Package Structure Convention

```
packages/
├── entity/                    # ENGINE: Core entity primitive
├── components/                # GAME: Pure data components
│   ├── health/
│   │   ├── sources/health.move
│   │   └── Move.toml
│   └── ...
├── smart_components/          # GAME: Components with complex logic
│   └── ...
└── systems/                   # GAME: Stateless game logic
    ├── combat_sys/
    │   ├── sources/
    │   │   ├── entry.move
    │   │   ├── helpers.move
    │   │   ├── events.move
    │   │   └── version.move
    │   └── Move.toml
    └── ...
```

**Engine code** lives in `entity/` (and any utility packages). **Game code** lives in `components/`, `smart_components/`, and `systems/`.

## Dependency Rules

```
Entity (engine) ← Components ← Systems
                    ↑                ↑
                 Configs          Configs
```

- Entity depends on nothing (or only Sui framework)
- Components depend on `entity`
- Systems depend on `entity` + all components they use
- **No circular deps** — components never depend on systems
- **Systems never depend on other systems** — compose at the game layer

## Reference Files — Conventions the Engine Defines

These document the patterns your engine enforces. When building engine primitives, these are the design rules you're encoding. When game-building AIs use the engine later, they follow these conventions.

| File | Convention It Defines |
|------|----------------------|
| [entity_reference.md](./references/entity_reference.md) | Entity API — what to expose, what to keep minimal |
| [component_reference.md](./references/component_reference.md) | Component shape — abilities, keys, struct categories, anti-patterns |
| [system_reference.md](./references/system_reference.md) | System structure — entry/helpers/events split, visibility rules |
| [config_reference.md](./references/config_reference.md) | Registry pattern — inline vs dynamic field config |
| [events_reference.md](./references/events_reference.md) | Event contract — struct rules, emit patterns |
| [testing_reference.md](./references/testing_reference.md) | Testing conventions — test_scenario, clock, helpers |
| [project_setup.md](./references/project_setup.md) | Package layout — Move.toml, directory structure, dependency graph |

## Example Templates — Reference Implementations for Game-Building AIs

These templates ship with your engine. Other AIs will copy these as starting points when building games. They also serve as a litmus test: if the template code feels awkward or verbose, the engine API needs improvement.

| Template | What It Proves |
|----------|---------------|
| [simple_component.move](./examples/simple_component.move) | The component convention is simple and predictable |
| [component_with_config.move](./examples/component_with_config.move) | Registry config integrates cleanly with components |
| [system_template/](./examples/system_template/) | The entry/helpers/events split works for real systems |

