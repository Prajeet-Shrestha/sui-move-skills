# Collections Modules

> Covers `sui::bag`, `sui::table`, `sui::object_bag`, `sui::object_table`, `sui::vec_map`, `sui::vec_set`, `sui::linked_table`, `sui::priority_queue`

## Quick Reference

| Module | Type | Backed By | Key Constraint | Value Constraint | Iterable | Size Limit |
|--------|------|-----------|---------------|-----------------|----------|------------|
| `vec_set` | `VecSet<T>` | Vector | N/A (set) | `copy + drop` | Yes | Object size |
| `vec_map` | `VecMap<K,V>` | Vector | `copy` | Any | Yes | Object size |
| `table` | `Table<K,V>` | Dynamic fields | `copy+drop+store` | `store` | No | Unlimited |
| `bag` | `Bag` | Dynamic fields | `copy+drop+store` | `store` | No | Unlimited |
| `object_table` | `ObjectTable<K,V>` | Dynamic object fields | `copy+drop+store` | `key+store` | No | Unlimited |
| `object_bag` | `ObjectBag` | Dynamic object fields | `copy+drop+store` | `key+store` | No | Unlimited |
| `linked_table` | `LinkedTable<K,V>` | Dynamic fields | `copy+drop+store` | `store` | Yes (linked) | Unlimited |
| `priority_queue` | `PriorityQueue<T>` | Vector | N/A | `drop` | Pop-only | Object size |

---

## `sui::vec_set` — Unique Set

In-memory set backed by a vector. Best for small sets (< 100 items).

```move
use sui::vec_set;

let mut set = vec_set::empty<address>();
set.insert(@0x1);               // aborts on duplicate
set.insert(@0x2);
assert!(set.contains(&@0x1));   // true
set.remove(&@0x1);              // aborts if not found
let size = set.size();          // 1
let keys = set.into_keys();     // consumes set → vector<address>
```

**Abilities**: `VecSet<T>` has `copy, drop, store` (when `T` has them)

---

## `sui::vec_map` — Small Key-Value Map

In-memory ordered map backed by a vector. Best for small maps (< 100 items).

```move
use sui::vec_map;

let mut map = vec_map::empty<String, u64>();
map.insert(b"gold".to_string(), 100);
let val = map[&b"gold".to_string()];         // index access: 100
let has = map.contains(&b"gold".to_string()); // true
let (key, val) = map.remove(&b"gold".to_string()); // returns both
let size = map.size();                        // 0
map.destroy_empty();                          // aborts if non-empty

// Destructuring
let (keys, values) = map.into_keys_values(); // consumes map
```

**Abilities**: `VecMap<K,V>` has `copy, drop, store` (when K, V have them)

---

## `sui::table` — Large Homogeneous Map

Dynamic field-backed key-value store. No size limit. Values are lazily loaded.

```move
use sui::table;

let mut t = table::new<address, u64>(ctx); // requires TxContext
t.add(@0x1, 100);                          // aborts if key exists
let val: &u64 = &t[@0x1];                  // immutable borrow
let val_mut: &mut u64 = &mut t[@0x1];      // mutable borrow
let removed = t.remove(@0x1);              // returns value
let has = t.contains(@0x1);                // false now
let len = t.length();                      // 0
let empty = t.is_empty();                  // true
t.destroy_empty();                         // aborts if non-empty
```

**Abilities**: `Table<K,V>` has `key, store` (it's a Sui object internally)

**Important**: Table has a `UID` internally — you can't `copy` or `drop` it. Must explicitly `destroy_empty()`.

---

## `sui::bag` — Heterogeneous Collection

Dynamic field-backed collection that allows **different value types** per key. No size limit.

```move
use sui::bag;

let mut b = bag::new(ctx);
b.add(b"name", b"Alice".to_string());    // String value
b.add(b"score", 42u64);                   // u64 value
b.add(b"alive", true);                    // bool value

let name: &String = b.borrow(b"name");
let score: &mut u64 = b.borrow_mut(b"score");

let has = b.contains(b"name");            // true
let has_typed = b.contains_with_type<vector<u8>, String>(b"name"); // true
let len = b.length();                     // 3

let removed: String = b.remove(b"name");
b.destroy_empty();                        // must remove all first
```

**Abilities**: `Bag` has `key, store`

**Key difference from Table**: Keys and values can have different types across entries. The type is specified at each call site.

---

## `sui::object_table` / `sui::object_bag`

Same API as `Table`/`Bag`, but backed by `dynamic_object_field` instead of `dynamic_field`.

**When to use**: When stored values are objects (`key + store`) and you need their IDs visible to off-chain tools (explorers, indexers).

```move
use sui::object_table;

let mut ot = object_table::new<String, Weapon>(ctx);
ot.add(b"sword".to_string(), sword);  // sword must have key+store
let w: &Weapon = &ot[b"sword".to_string()];
// sword's object ID is visible in explorers
```

API is identical to `Table`/`Bag` respectively. Only the storage layer differs.

---

## `sui::linked_table` — Ordered Map with Iteration

Dynamic field-backed map with linked-list ordering. Supports traversal.

```move
use sui::linked_table;

let mut lt = linked_table::new<u64, String>(ctx);
lt.push_back(1, b"first".to_string());
lt.push_back(2, b"second".to_string());
lt.push_front(0, b"zeroth".to_string());

// Traversal
let front: &Option<u64> = lt.front();   // Some(0)
let back: &Option<u64> = lt.back();     // Some(2)
let next: &Option<u64> = lt.next(0);    // Some(1)
let prev: &Option<u64> = lt.prev(1);    // Some(0)

// Access
let val: &String = &lt[1];
let val_mut: &mut String = &mut lt[1];

// Removal
let (key, val) = lt.pop_front();         // removes first
let (key, val) = lt.pop_back();          // removes last
let val = lt.remove(1);                  // removes by key

let len = lt.length();
let empty = lt.is_empty();
lt.destroy_empty();
```

**Engine uses**: Leaderboards, ordered queues, turn order, LRU caches.

---

## `sui::priority_queue` — Min-Heap

In-memory priority queue. Backed by vector. Values popped in **ascending** priority order.

```move
use sui::priority_queue;

// Create from entries: vector of (priority, value) pairs
let entries = vector[
    priority_queue::new_entry(3, b"low"),
    priority_queue::new_entry(1, b"high"),
    priority_queue::new_entry(2, b"medium"),
];
let mut pq = priority_queue::create_entries(entries);

// Pop in ascending priority order
let (priority, value) = pq.pop_max();   // (3, b"low") — highest priority number first
// NOTE: despite the name, this is a MAX-heap (highest priority number pops first)

pq.insert(0, b"urgent");               // add new entry
```

**Abilities**: `PriorityQueue<T>` has `store, drop` (when T has them)

**Engine uses**: Turn scheduling (initiative order), event processing queues.

---

## Engine Recommendations

| ECS Concept | Best Collection | Why |
|-------------|----------------|-----|
| Component data fields | struct fields or `VecMap` | Small, known at compile time |
| Component attachment | `dynamic_field` (raw) | Not a collection — direct UID attachment |
| Inventory (many typed items) | `Bag` | Heterogeneous items |
| Inventory (same-type items) | `Table` | Homogeneous, unlimited |
| Equipment with visible IDs | `ObjectBag` or `ObjectTable` | Object identity preserved |
| Leaderboard | `LinkedTable` | Ordered, iterable |
| Turn order / initiative | `PriorityQueue` | Sorted pop |
| Tags / status effects | `VecSet` | Small, unique |
| Config key-value | `VecMap` or `dynamic_field` | Depends on size |
