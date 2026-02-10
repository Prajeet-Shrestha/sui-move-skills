# Token Modules

> Covers `sui::coin`, `sui::balance`, `sui::display`

## `sui::balance` — Storable Token Amounts

`Balance<T>` is the **inner representation** of fungible token amounts. Unlike `Coin`, it has `store` but not `key`, so it can be embedded in structs without being a standalone object.

### Key Types

```move
/// Storable balance. Embed in structs for in-game currency.
public struct Balance<phantom T> has store {
    value: u64,
}

/// Supply tracker. Controls minting. Wrapped inside TreasuryCap.
public struct Supply<phantom T> has store {
    value: u64,
}
```

### API

```move
use sui::balance;

// Create
balance::zero<T>(): Balance<T>                         // empty balance

// Read
balance.value(): u64                                    // current amount

// Mutate
balance.join(other: Balance<T>): u64                   // merge, returns new total
balance.split(amount: u64): Balance<T>                 // split off amount
balance.withdraw_all(): Balance<T>                     // take everything

// Destroy
balance.destroy_zero()                                  // aborts if non-zero

// Supply operations (for minting)
balance::create_supply<T>(witness: T): Supply<T>       // create supply (OTW required)
supply.increase_supply(amount: u64): Balance<T>        // mint
supply.decrease_supply(balance: Balance<T>): u64       // burn, returns amount burned
supply.supply_value(): u64                             // total minted
```

### Engine Pattern: In-Game Currency Store

```move
public struct Treasury has key {
    id: UID,
    gold: Balance<GOLD>,     // embedded, not a separate object
    gems: Balance<GEMS>,
}

public fun deposit_gold(treasury: &mut Treasury, payment: Coin<GOLD>) {
    treasury.gold.join(coin::into_balance(payment));
}

public fun withdraw_gold(treasury: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<GOLD> {
    let balance = treasury.gold.split(amount);
    coin::from_balance(balance, ctx)
}
```

### Balance vs Coin

| Feature | `Balance<T>` | `Coin<T>` |
|---------|-------------|-----------|
| Abilities | `store` | `key, store` |
| Is a Sui object | No | Yes (has UID) |
| Can embed in structs | Yes | No (would nest objects) |
| Can transfer directly | No | Yes |
| Gas cost | Lower | Higher (object overhead) |
| Use for | Internal accounting | User-facing transfers |

**Rule of thumb**: Use `Balance<T>` inside your engine structs, convert to `Coin<T>` only when transferring to users.

---

## `sui::coin` — Fungible Tokens

Full token standard: creation, minting, burning, metadata.

### Key Types

```move
/// A coin object. Wraps Balance<T> with a UID.
public struct Coin<phantom T> has key, store {
    id: UID,
    balance: Balance<T>,
}

/// Capability to mint/burn. Created once via create_currency.
public struct TreasuryCap<phantom T> has key, store {
    id: UID,
    total_supply: Supply<T>,
}

/// Metadata (name, symbol, decimals, icon).
public struct CoinMetadata<phantom T> has key, store { ... }
```

### Creating a Currency

```move
module my_game::gold {
    use sui::coin;

    /// One-Time Witness (must match module name, uppercase)
    public struct GOLD has drop {}

    fun init(witness: GOLD, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,          // OTW consumed here
            9,                // decimals
            b"GOLD",          // symbol
            b"Game Gold",     // name
            b"In-game currency", // description
            option::none(),   // icon_url
            ctx,
        );

        // Share metadata (read-only for explorers)
        transfer::public_freeze_object(metadata);

        // Transfer treasury cap to admin
        transfer::public_transfer(treasury_cap, ctx.sender());
    }
}
```

### Coin Operations

```move
use sui::coin;

// Value
coin.value(): u64                              // amount in coin
coin.balance(): &Balance<T>                    // borrow inner balance

// Conversions
coin::into_balance(coin: Coin<T>): Balance<T>  // consume coin → balance
coin::from_balance(b: Balance<T>, ctx): Coin<T> // balance → new coin

// Split/Join
coin.split(amount: u64, ctx): Coin<T>         // split off amount into new coin
coin.join(other: Coin<T>)                      // merge other into self
coin.divide_into_n(n: u64, ctx): vector<Coin<T>> // split into n equal coins

// Mint/Burn (requires TreasuryCap)
coin::mint(cap: &mut TreasuryCap<T>, amount: u64, ctx): Coin<T>
coin::mint_balance(cap: &mut TreasuryCap<T>, amount: u64): Balance<T>
coin::burn(cap: &mut TreasuryCap<T>, coin: Coin<T>): u64

// Transfer helper
coin::mint_and_transfer(cap, amount, recipient, ctx)

// Supply info
cap.total_supply(): u64

// Zero coin
coin::zero<T>(ctx): Coin<T>                   // 0-value coin
coin.destroy_zero()                            // aborts if non-zero

// Balance operations via coin
coin::take(balance: &mut Balance<T>, amount: u64, ctx): Coin<T>  // take from balance as coin
coin::put(balance: &mut Balance<T>, coin: Coin<T>)               // put coin into balance
```

### Engine Pattern: Reward Distribution

```move
public fun claim_reward(
    treasury: &mut TreasuryCap<GOLD>,
    amount: u64,
    ctx: &mut TxContext,
) {
    // Mint and send directly to player
    coin::mint_and_transfer(treasury, amount, ctx.sender(), ctx);
}
```

---

## `sui::display` — Object Display Metadata

Controls how objects appear in wallets, explorers, and marketplaces. Uses a **template string** system.

### Creating Display

```move
use sui::display;
use sui::package::Publisher;

public struct Monster has key, store {
    id: UID,
    name: String,
    level: u64,
    image_url: String,
}

fun init(otw: MONSTERS, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let mut display = display::new<Monster>(&publisher, ctx);
    display.add(b"name".to_string(), b"{name}".to_string());
    display.add(b"description".to_string(), b"Level {level} monster".to_string());
    display.add(b"image_url".to_string(), b"{image_url}".to_string());
    display.add(b"project_url".to_string(), b"https://mygame.com".to_string());

    // Commit the display (makes it active)
    display.update_version();

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(display, ctx.sender());
}
```

### Template Syntax

Templates use `{field_name}` to interpolate struct fields:

| Template | Result for `Monster { name: "Dragon", level: 5, ... }` |
|----------|-------------------------------------------------------|
| `{name}` | `Dragon` |
| `Level {level} monster` | `Level 5 monster` |
| `https://api.game.com/img/{name}.png` | `https://api.game.com/img/Dragon.png` |

### Standard Display Fields

| Field | Description |
|-------|------------|
| `name` | Object name |
| `description` | Object description |
| `image_url` | Primary image |
| `project_url` | Project website |
| `link` | Link to object details |
| `creator` | Creator name |
| `thumbnail_url` | Smaller preview image |

### Engine Use

Display is set up once per type during package publish (`init`). It's primarily for entities, items, or any objects that users see in wallets.
