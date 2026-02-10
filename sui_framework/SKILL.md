---
name: Sui Framework Modules
description: Quick reference for Sui Framework modules used in on-chain game engine development. Covers object identity, dynamic fields, transfer, events, clock, randomness, coins/balances, and package management.
---

# Sui Framework Modules

API reference for Sui Framework modules relevant to game engine development. Use this when writing actual Move code and you need the exact function signatures, type constraints, or usage patterns.

> **Source**: All content is distilled from the [Sui Framework reference](https://docs.sui.io/references/framework/sui).

## Module Decision Matrix

Use this to pick the right module for your task:

### "I need to manage object identity"

| Need | Module | Function |
|------|--------|----------|
| Create a new UID | `sui::object` | `object::new(ctx)` |
| Delete a UID | `sui::object` | `uid.delete()` |
| Get ID from object | `sui::object` | `object::id(&obj)` → `ID` |
| Convert UID → ID | `sui::object` | `uid.to_inner()` |
| Convert ID → address | `sui::object` | `id.to_address()` |

### "I need to store/retrieve data on an object"

| Need | Module | Function |
|------|--------|----------|
| Attach a value (wraps, no object ID) | `sui::dynamic_field` | `df::add(&mut uid, name, value)` |
| Read attached value | `sui::dynamic_field` | `df::borrow(&uid, name)` |
| Mutate attached value | `sui::dynamic_field` | `df::borrow_mut(&mut uid, name)` |
| Remove attached value | `sui::dynamic_field` | `df::remove(&mut uid, name)` |
| Check existence | `sui::dynamic_field` | `df::exists_(&uid, name)` |
| Attach an object (preserves object ID) | `sui::dynamic_object_field` | `dof::add(&mut uid, name, obj)` |

### "I need to transfer/share an object"

| Need | Module | Function |
|------|--------|----------|
| Transfer to address (same module) | `sui::transfer` | `transfer::transfer(obj, recipient)` |
| Transfer to address (cross-module) | `sui::transfer` | `transfer::public_transfer(obj, recipient)` |
| Make shared (irreversible) | `sui::transfer` | `transfer::share_object(obj)` |
| Make immutable (irreversible) | `sui::transfer` | `transfer::freeze_object(obj)` |

### "I need game infrastructure"

| Need | Module | Function |
|------|--------|----------|
| Current timestamp (ms) | `sui::clock` | `clock.timestamp_ms()` |
| Generate random numbers | `sui::random` | `random::new_generator(r, ctx)` → `gen.generate_u64()` |
| Emit off-chain event | `sui::event` | `event::emit(event_struct)` |
| Integer math | `sui::math` | `math::min(a, b)`, `math::max(a, b)` |

### "I need tokens/currency"

| Need | Module | Function |
|------|--------|----------|
| Create a new coin type | `sui::coin` | `coin::create_currency(witness, ...)` |
| Mint coins | `sui::coin` | `coin::mint(&mut cap, amount, ctx)` |
| Store balance in a struct | `sui::balance` | `Balance<T>` (has `store`, no `key`) |
| Split/join balances | `sui::balance` | `balance::split()`, `balance::join()` |
| Convert Coin ↔ Balance | `sui::coin` | `coin::into_balance(c)`, `coin::from_balance(b, ctx)` |

### "I need package management"

| Need | Module | Function |
|------|--------|----------|
| Prove package identity | `sui::package` | `package::claim(otw)` → `Publisher` |
| Restrict upgrade policy | `sui::package` | `cap.only_additive_upgrades()` |
| Make package immutable | `sui::package` | `cap.make_immutable()` |
| Get transaction sender | `sui::tx_context` | `ctx.sender()` |
| Get current epoch | `sui::tx_context` | `ctx.epoch()` |

## Reference Files

| File | What It Covers |
|------|---------------|
| [storage_modules.md](./references/storage_modules.md) | `object`, `dynamic_field`, `dynamic_object_field`, `transfer` — identity, storage, ownership |
| [collections_modules.md](./references/collections_modules.md) | `bag`, `table`, `vec_map`, `vec_set`, `linked_table`, `priority_queue` — framework collections |
| [game_modules.md](./references/game_modules.md) | `clock`, `random`, `event`, `math` — game infrastructure |
| [token_modules.md](./references/token_modules.md) | `coin`, `balance`, `display` — fungible tokens, metadata |
| [package_and_context.md](./references/package_and_context.md) | `package`, `tx_context` — deployment, identity, upgrades |
