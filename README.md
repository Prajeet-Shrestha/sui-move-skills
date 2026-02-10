# Agent Skills — ECS Game Engine on Sui

These skills teach an AI agent how to build a **reusable on-chain ECS game engine on Sui Move**. Read them in order — each skill builds on the previous one.

## Skills

| # | Skill | What It Teaches |
|---|-------|----------------|
| 1 | [Sui Move Patterns](./sui_move_patterns/SKILL.md) | **Language foundations** — object model, abilities, dynamic fields, design patterns (Capability, Witness, Hot Potato), visibility, API design |
| 2 | [Sui Framework Modules](./sui_framework/SKILL.md) | **Framework API reference** — exact function signatures for `object`, `dynamic_field`, `transfer`, `clock`, `random`, `coin`, `table`, `bag`, etc. |
| 3 | [Sui Engineering Practices](./sui_engineering/SKILL.md) | **Production quality** — upgradeability, gas optimization, protocol limits, error handling, code quality checklist |
| 4 | [ECS Game Engine Principles](./game_engine/SKILL.md) | **Engine architecture** — Entity-Component-System on Sui, conventions for entities, components, systems, configs, events, and testing |

## How to Use

1. **Building the engine?** Start with Skills 1-3 for Sui Move fundamentals, then use Skill 4 for ECS architecture decisions.
2. **Building a game on the engine?** Read Skill 4's reference files and copy the example templates as starting points.
3. **Looking up a specific API?** Go directly to Skill 2's decision matrix tables.
4. **Reviewing code?** Check Skill 3's code quality checklist and error handling conventions.

## Structure

Each skill follows the same layout:

```
skill_name/
├── SKILL.md          # Overview, decision matrices, links to references
└── references/       # Detailed docs on specific topics
```

Skill 4 (`game_engine`) also includes:
```
game_engine/
└── examples/         # Copy-paste templates for components and systems
```
