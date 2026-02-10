# Abilities & Generics

> Source: [Move Book Ch 5.7, 5.22, 5.24–5.25, 7.2–7.3](https://move-book.com/move-basics/abilities-introduction)

## The Four Abilities

| Ability | What It Allows | Required For |
|---------|---------------|-------------|
| `key` | Struct is a Sui object (has UID) | Objects stored on-chain |
| `store` | Can be stored inside other objects | Dynamic fields, collections |
| `copy` | Can be duplicated | Value types, intermediate results |
| `drop` | Can be implicitly discarded | Witnesses, temporary values |

## Common Ability Combinations

| Combination | Use Case | Example |
|-------------|----------|---------|
| `has key` | Standalone object (entity, registry) | `Entity`, `AdminCap` |
| `has key, store` | Object that can also be nested in other objects | `Accessory`, `Item` |
| `has store, copy, drop` | Lightweight component (pure data) | `Health`, `Position` |
| `has store, drop` | Component with non-copyable fields (`String`, `Url`) | `Metadata`, `Profile` |
| `has store` | Component that manages resources (cannot be freely duplicated/dropped) | Careful — hard to use |
| `has copy, drop` | Event struct | `AttackEvent`, `MoveEvent` |
| (none) | Hot Potato — must be consumed | `Request`, `Promise` |

## Ability Rules

- `key` requires the **first field** to be `id: UID`
- A struct can only have abilities that all its fields also have
  - If a field has `String` (which has `copy + drop + store`), the struct can have `copy + drop + store`
  - If a field has `UID` (which only has `store`), the struct cannot have `copy` or `drop`
- `key` structs must also have `store` on all fields

## Generics

Generics allow writing type-parameterized code:

```move
// Generic function — works with any T that has store
public fun wrap<T: store>(value: T): Wrapper<T> {
    Wrapper { value }
}
```

### Generic Constraints

You can constrain type parameters:

```move
// T must have key + store (i.e., must be an object)
public fun take<T: key + store>(obj: T) { ... }

// T must have drop (can be thrown away)
public fun create_supply<T: drop>(_witness: T): Supply<T> { ... }
```

### Phantom Type Parameters

When a type parameter is only used for type-level tagging (not stored):

```move
public struct Balance<phantom T> has store {
    value: u64,
}
```

`phantom` means:
- `T` doesn't appear in any field
- `T`'s abilities don't constrain the struct's abilities
- Used for type-safe tagging (e.g., `Balance<SUI>` vs `Balance<USDC>`)

## Type Reflection

Get type information at runtime:

```move
use std::type_name;

let name: TypeName = type_name::get<Health>();
// Returns the fully qualified type name as a string
```

Useful for:
- Debug logging
- Generic component key generation
- Runtime type checks
