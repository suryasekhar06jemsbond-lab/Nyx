# Nyx Ownership & Borrowing System

## Overview

Nyx implements a Rust-inspired ownership system that provides memory safety guarantees without requiring a garbage collector. The system ensures:

- **Memory Safety**: No use-after-free, no double-free errors
- **Data Race Prevention**: At compile time, no data races can occur
- **Zero-Cost Abstractions**: The borrow checker operates at compile time
- **Deterministic Cleanup**: RAII-based resource management

---

## Core Principles

### 1. Every Value Has Exactly One Owner

```nyx
let s = String::new("hello");
# s is the sole owner of the String value

let s2 = s;  # Ownership is MOVEd to s2
# s is now invalid - cannot be used
```

### 2. References (Borrows) Provide Access Without Ownership

```nyx
fn len(s: &str) -> int {
    # Borrowed reference - no ownership
    return s.length;
}
```

### 3. Mutable References Are Exclusive

```nyx
let mut value = 10;
let r1 = &mut value;  # Exclusive mutable borrow
# Cannot create any other borrows while r1 is active
```

---

## Ownership Rules

### Move Semantics

By default, assigning a value transfers ownership (move):

```nyx
let original = [1, 2, 3];
let moved = original;  # Move - original is invalidated
# print(original);  # ERROR: original no longer valid
print(moved);        # OK: moved owns the data
```

### Copy Types

Primitive types (`int`, `bool`, `f64`) are Copy types - they implement copy semantics:

```nyx
let a = 42;
let b = a;  # Copy - both a and b are valid
print(a);   # OK: a is still valid
print(b);   # OK: b has a copy
```

---

## Borrowing

### Immutable Borrows

Create shared references with `&`:

```nyx
let value = 42;
let borrowed: &int = &value;

print(*borrowed);  # 42

# Multiple immutable borrows are allowed
let b2: &int = &value;
let b3: &int = &value;
```

### Mutable Borrows

Create exclusive references with `&mut`:

```nyx
let mut value = 10;
let mutable_ref: &mut int = &mut value;

*mutable_ref = 20;  # Modify the value
print(value);       # 20
```

### Borrow Rules

| Rule | Description |
|------|-------------|
| 1 | You can have **either** one mutable borrow **OR** any number of immutable borrows |
| 2 | Borrows must not outlive their referent |
| 3 | Mutable data cannot be borrowed immutably while mutably borrowed |

---

## Lifetimes

### Lifetime Annotations

Lifetimes track how long references are valid:

```nyx
fn longest<'a>(s1: &'a str, s2: &'a str) -> &'a str {
    if (s1.length > s2.length) {
        return s1;
    }
    return s2;
}
```

The `'a` lifetime represents the minimum lifetime of both inputs and output.

### Lifetime Elision

Nyx infers lifetimes in common patterns:

```nyx
fn get_first(s: &str) -> &str {
    # Elided to: fn get_first<'a>(s: &'a str) -> &'a str
    return &s[0:1];
}
```

---

## RAII - Resource Acquisition Is Initialization

### Deterministic Resource Management

Resources are automatically cleaned up when they go out of scope:

```nyx
class File {
    path: str;
    handle: FileHandle;
    
    fn new(path: str) {
        self.path = path;
        self.handle = open(path);  # Acquire resource
    }
    
    # Destructor - called automatically
    fn drop(self) {
        close(self.handle);  # Release resource
    }
}

fn process_file() {
    let file = File("data.txt");
    # Use file...
}  # file.drop() called automatically
```

### Explicit Lifetime Management

```nyx
{
    let resource = acquire_resource();
    # Use resource...
}  # Automatic cleanup
```

---

## The Borrow Checker

### What the Borrow Checker Prevents

1. **Dangling References**

   ```nyx
   fn dangling() -> &int {
       let x = 10;
       return &x;  # ERROR: x is dropped at end of function
   }
   ```

2. **Use After Move**

   ```nyx
   fn use_after_move() {
       let s = String::new("hello");
       let s2 = s;  # Move
       print(s);     # ERROR: s was moved
   }
   ```

3. **Data Races**

   ```nyx
   fn data_race() {
       let mut data = 0;
       
       let r1 = &mut data;
       let r2 = &data;  # ERROR: concurrent mutable and immutable
   }
   ```

### Borrow Checker Errors

| Error | Description | Example |
|-------|-------------|---------|
| `E0501` | Cannot borrow as mutable because it's also borrowed as immutable | `&x` and `&mut x` |
| `E0502` | Cannot borrow as immutable because it's also borrowed as mutable | `&mut x` and `&x` |
| `E0503` | Cannot drop value while borrowed | Drop while `&` exists |
| `E0505` | Cannot move out of value that's borrowed | Move value with active borrows |

---

## Smart Pointers

### Box<T> - Heap Allocation

```nyx
let boxed = Box::new(42);
let value = *boxed;  # Dereference to get value

let ref: &int = &boxed;  # Borrow the Box
```

### Rc<T> - Reference Counting

```nyx
let a = Rc::new(42);
let b = Rc::clone(&a);  # Reference count = 2

fn process(rc: Rc<int>) {
    # Can clone again if needed
}
```

### Arc<T> - Atomic Reference Counting

Thread-safe reference counting:

```nyx
use std::sync::Arc;

let shared = Arc::new([1, 2, 3]);
spawn(fn() {
    let local = Arc::clone(&shared);
    # Safe to use in another thread
});
```

---

## Ownership in Functions

### Passing by Value (Move)

```nyx
fn consume(s: String) {
    print(s);
}  # s is dropped here

fn main() {
    let s = String::new("hello");
    consume(s);  # Ownership moves to consume
    # print(s);  # ERROR: s was moved
}
```

### Passing by Reference (Borrow)

```nyx
fn borrow(s: &String) {
    print(*s);
}  # s is dropped here (reference, not owned)

fn main() {
    let s = String::new("hello");
    borrow(&s);  # Borrow s
    print(s);    # OK: still owner
}
```

### Borrowing Mutably

```nyx
fn modify(s: &mut String) {
    s.push_str(" world");
}

fn main() {
    let mut s = String::new("hello");
    modify(&mut s);
    print(s);  # "hello world"
}
---

## Methods and Self

### Immutable Reference Receiver

```nyx
class Counter {
    value: int;
    
    fn new(initial: int) {
        self.value = initial;
    }
    
    fn get(self: &Counter) -> int {
        return self.value;
    }
}
```

### Mutable Reference Receiver

```nyx
class Counter {
    value: int;
    
    fn increment(self: &mut Counter) {
        self.value = self.value + 1;
    }
}
```

### Owned Self

```nyx
class Resource {
    fn consume(self: Self) {
        # Takes ownership of self
    }
}
```

---

## Lifetime Variances

### `'static

Static lifetime - data lives for the entire program:

```nyx
const MESSAGE: &'static str = "Hello, world!";
```

### Higher-Rank Trait Bounds (HRTB)

```nyx
fn call_twice(f: fn(&int)) {
    let x = 10;
    f(&x);
    f(&x);
}
```

---

## Advanced Topics

### Lifetimes in Structs

```nyx
struct StringView<'a> {
    data: &'a str,
}

fn first_word(s: &str) -> StringView {
    let end = s.find(" ").unwrap_or(s.len());
    return StringView { data: &s[0:end] };
}
```

### NLL (Non-Lexical Lifetimes)

Nyx uses Non-Lexical Lifetimes, extending borrow validity beyond the lexical scope:

```nyx
let mut x = 10;
let y = &x;
print(y);   # y's borrow ends here
x = 20;     # OK: no longer borrowed
```

### Subtyping and Coercion

- `&T` is a subtype of `&T` (identity)
- `'a: 'b` ( `'a` outlives `'b`)
- Unsafe traits can enable additional coercions

---

## Formal Properties

### Soundness Guarantees

The ownership system provides formal proofs for:

1. **Memory Safety**: No invalid memory access
2. **Type Safety**: No type confusion attacks
3. **Data Race Freedom**: No concurrent mutation without synchronization

### Theoretical Foundation

Based on:
- Linear logic (ownership transfer)
- Affine logic (at most one mutable reference)
- Region-based memory management

---

## Best Practices

### Do

- Use borrows for read-only access
- Use `&mut` for exclusive modification
- Let the compiler infer lifetimes when possible
- Use RAII for resource management

### Don't

- Don't return references to local variables
- Don't mix borrows of different mutability
- Don't hold references longer than needed
- Don't fight the borrow checker - it's protecting you

---

## Summary

| Concept | Symbol | Description |
|---------|--------|-------------|
| Ownership | - | Each value has exactly one owner |
| Move | `let x = y` | Transfer ownership |
| Borrow | `&x` | Immutable reference |
| Mutable Borrow | `&mut x` | Exclusive mutable reference |
| Lifetime | `'a` | Duration of reference validity |
| RAII | `drop()` | Deterministic cleanup |
