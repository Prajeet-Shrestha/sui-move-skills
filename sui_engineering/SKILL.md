---
name: Sui Engineering Practices
description: Production engineering practices for Sui Move — upgradeability, gas/limits, error handling, testing, and code quality. Reference when writing, reviewing, or debugging on-chain code.
---

# Sui Engineering Practices

Best practices for building production-quality Sui Move code. Use this when writing systems, reviewing code, or debugging issues.

> **Source**: Distilled from [The Move Book — Guides](https://move-book.com/guides) and Sui ecosystem conventions.

## Quick Decision Matrix

### "I'm designing module visibility"

| Visibility | Removable on Upgrade | Can Return Values | Callable From |
|-----------|---------------------|-------------------|---------------|
| `public fun` | ❌ Never | ✅ Yes | Anywhere (PTBs, other packages) |
| `public(package) fun` | ✅ Yes | ✅ Yes | Same package only |
| `entry fun` | ✅ Yes | ❌ No | PTBs only (not composable) |
| `fun` (private) | ✅ Yes | ✅ Yes | Same module only |

**Rule**: Default to `public fun` for composable APIs. Use `entry fun` only when you intentionally want to prevent composability (e.g., randomness consumers).

### "I'm hitting a limit"

| Limit | Value | Workaround |
|-------|-------|-----------|
| Transaction size | 128 KB | Batch operations across multiple PTB commands |
| Object size | 256 KB | Use dynamic fields (Bag/Table) for overflow |
| Pure argument size | 16 KB | Join vectors dynamically in Move or PTB |
| Objects created per tx | 2,048 | Batch across transactions |
| Dynamic fields created per tx | 1,000 | Batch across transactions |
| Dynamic fields accessed per tx | 1,000 | Minimize reads per operation |
| Events emitted per tx | 1,024 | Aggregate events, emit summaries |

### "I need to handle an error"

| Pattern | When to Use |
|---------|-------------|
| `assert!(condition, EErrorName)` | Guard at function entry |
| `if (!check) return/abort` | Non-fatal early exit |
| Return `bool` from checks | Let callers handle errors their way |
| Unique error constant per check | Always — never reuse codes |

## Reference Files

| File | What It Covers |
|------|---------------|
| [upgradeability.md](./references/upgradeability.md) | Compatibility rules, version guards, config anchoring |
| [gas_and_limits.md](./references/gas_and_limits.md) | Protocol limits, gas optimization patterns |
| [error_handling.md](./references/error_handling.md) | Error constants, assertion patterns, abort codes |
| [code_quality.md](./references/code_quality.md) | Naming, imports, structs, functions, macros, testing conventions |
