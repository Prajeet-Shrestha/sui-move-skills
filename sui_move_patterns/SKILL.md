---
name: Sui Move Patterns
description: Sui Move language patterns essential for building on-chain applications. Covers the object model, abilities, dynamic fields, collections, design patterns (Capability, Witness, Hot Potato), and API design conventions.
---

# Sui Move Patterns

Language-level patterns for building on Sui Move. This skill covers the **how** — the Sui-specific Move patterns you need when writing engine code, components, or systems.

> **Source**: All content is distilled from [The Move Book](https://move-book.com/) and the [Sui Framework reference](https://docs.sui.io/references/framework/sui_sui).

## Quick Decision Matrix

Use this when you need to choose a pattern:

### "How should I store this data?"

| Situation | Use | Why |
|-----------|-----|-----|
| Fixed fields known at compile time | Regular struct fields | Cheapest, fastest |
| Unknown/extensible fields at runtime | `dynamic_field` | Lazy loading, no schema migrations |
| Storing objects that need off-chain ID lookup | `dynamic_object_field` | Preserves object identity (2x cost) |
| Small set of unique items (<100) | `VecSet` | In-memory, object-local |
| Small key-value map (<100) | `VecMap` | In-memory, object-local |
| Large key-value map (100+) | `Table` | Dynamic field-backed, no size limit |
| Heterogeneous collection | `Bag` | Dynamic field-backed, mixed types |

### "How should I control access?"

| Situation | Use |
|-----------|-----|
| Admin-only operations | Capability pattern (`AdminCap` object) |
| Prove package identity | Witness pattern (struct from module) |
| Ensure multi-step completion | Hot Potato (no-ability struct) |
| Player owns their data | Single-owner objects (transfer to sender) |
| Shared game state anyone can interact with | Shared objects (`share_object`) |

### "What visibility should this function have?"

| Visibility | Who Can Call | Use For |
|------------|------------|---------|
| (none) | Same module only | Internal helpers |
| `public(package)` | Same package | Cross-module helpers within a system |
| `public` | Any package | Engine API, reusable utilities |
| `entry` | Transaction only (not other Move) | Top-level transaction endpoints |

## Reference Files

| File | What It Covers |
|------|---------------|
| [object_model.md](./references/object_model.md) | Object properties, 4 ownership types, fast path vs consensus |
| [abilities_and_generics.md](./references/abilities_and_generics.md) | `key`, `store`, `copy`, `drop`, phantom types, generic constraints |
| [dynamic_fields.md](./references/dynamic_fields.md) | `dynamic_field` vs `dynamic_object_field`, UID exposure, limits |
| [collections.md](./references/collections.md) | Vector, VecSet, VecMap, Table, Bag, LinkedTable — when to use each |
| [design_patterns.md](./references/design_patterns.md) | Capability, Witness, One-Time Witness, Hot Potato, Wrapper |
| [api_design.md](./references/api_design.md) | Visibility, receiver syntax, `init`, enums, error conventions |
