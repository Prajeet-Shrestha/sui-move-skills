# Collections

> Source: [Move Book Ch 8.6, 8.10](https://move-book.com/programmability/collections)

## Decision Matrix

| Collection | Backed By | Size Limit | Key Type | Value Type | Iteration | Use When |
|-----------|-----------|------------|----------|------------|-----------|----------|
| `vector<T>` | In-memory array | Object size limit | Index (u64) | Homogeneous | Yes | Small ordered lists |
| `VecSet<T>` | Vector | Object size limit | N/A (set) | Homogeneous | Yes | Small unique sets |
| `VecMap<K,V>` | Vector | Object size limit | Any w/ copy+drop | Homogeneous values | Yes | Small key-value maps |
| `Table<K,V>` | Dynamic fields | Unlimited | Any w/ copy+drop+store | Homogeneous | No | Large key-value maps |
| `Bag` | Dynamic fields | Unlimited | Any w/ copy+drop+store | **Heterogeneous** | No | Mixed-type collections |
| `ObjectTable<K,V>` | Dynamic object fields | Unlimited | Any w/ copy+drop+store | key+store objects | No | Large object maps |
| `ObjectBag` | Dynamic object fields | Unlimited | Any w/ copy+drop+store | key+store objects | No | Mixed-type object bags |
| `LinkedTable<K,V>` | Dynamic fields | Unlimited | Any w/ copy+drop+store | Homogeneous | Yes (linked) | Ordered maps, queues |

## In-Memory Collections (object-size limited)

### Vector

Native type. Ordered, iterable, homogeneous.

```move
let mut v = vector::empty<u64>();
v.push_back(10);
v.push_back(20);
let val = v[0];           // index access
let len = v.length();
let popped = v.pop_back();
```

### VecSet

Unique items. Aborts on duplicate insert.

```move
use sui::vec_set;

let mut set = vec_set::empty<address>();
set.insert(@0x1);
set.insert(@0x2);
assert!(set.contains(&@0x1));
set.remove(&@0x1);
```

### VecMap

Key-value pairs. Unique keys.

```move
use sui::vec_map;

let mut map = vec_map::empty<String, u64>();
map.insert(b"gold".to_string(), 100);
let gold = map[&b"gold".to_string()];
map.remove(&b"gold".to_string());
```

**Limitations of in-memory collections:**
- Subject to object size limit (~256KB serialized)
- Cannot compare two VecSets — order is insertion-dependent
- Best for < 100 items

## Dynamic Field Collections (unlimited)

### Table

Homogeneous key-value map backed by dynamic fields. No size limit.

```move
use sui::table;

let mut t = table::new<address, u64>(ctx);
t.add(@0x1, 100);
let val = t[&@0x1];
t.remove(@0x1);
t.destroy_empty();       // must be empty to destroy
```

### Bag

Heterogeneous collection — different value types per key.

```move
use sui::bag;

let mut b = bag::new(ctx);
b.add(b"name", b"Alice".to_string());    // String value
b.add(b"score", 42u64);                   // u64 value
let name: &String = b.borrow(b"name");
b.destroy_empty();
```

**Note**: `Bag` tracks its size. If you try to destroy a non-empty Bag, it aborts — preventing orphaned dynamic fields.

### LinkedTable

Ordered map with prev/next pointers. Supports iteration via linked traversal.

```move
use sui::linked_table;

let mut lt = linked_table::new<u64, String>(ctx);
lt.push_back(1, b"first".to_string());
lt.push_back(2, b"second".to_string());
let front = lt.front();     // Option<u64> → Some(1)
let back = lt.back();       // Option<u64> → Some(2)
```

Ideal for: leaderboards, ordered queues, LRU caches.

## Engine Recommendations

| ECS Concept | Best Collection |
|-------------|----------------|
| Component data fields | `VecMap` (small maps like resource storage) |
| Entity component attachments | `dynamic_field` (not a collection — raw df) |
| Inventory (many items) | `Bag` or `ObjectBag` |
| Leaderboard | `LinkedTable` |
| Registry per-key configs | `dynamic_field` on the Registry UID |
| Tag sets (e.g., status effects) | `VecSet` |
