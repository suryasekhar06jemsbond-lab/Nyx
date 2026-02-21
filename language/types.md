# Nyx Type System

## Overview

Nyx features a rich, expressive type system that provides safety guarantees while maintaining flexibility. The type system includes primitive types, compound types, user-defined types, and advanced features like generics and type inference.

---

## Primitive Types

### Integer Types

| Type | Description | Range |
|------|-------------|-------|
| `int` | Default integer | Platform-dependent (typically 64-bit) |
| `i8` | 8-bit signed | -128 to 127 |
| `i16` | 16-bit signed | -32,768 to 32,767 |
| `i32` | 32-bit signed | -2,147,483,648 to 2,147,483,647 |
| `i64` | 64-bit signed | -9,223,372,036,854,775,808 to 9,223,372,036,854,775,807 |
| `u8` | 8-bit unsigned | 0 to 255 |
| `u16` | 16-bit unsigned | 0 to 65,535 |
| `u32` | 32-bit unsigned | 0 to 4,294,967,295 |
| `u64` | 64-bit unsigned | 0 to 18,446,744,073,709,551,615 |

### Floating-Point Types

| Type | Description | Precision |
|------|-------------|-----------|
| `f32` | 32-bit float | IEEE 754 single-precision |
| `f64` | 64-bit double | IEEE 754 double-precision |

### Other Primitives

| Type | Description | Values |
|------|-------------|--------|
| `bool` | Boolean | `true`, `false` |
| `char` | Character | Single Unicode character |
| `str` | String | Immutable sequence of characters |

### Special Types

| Type | Description |
|------|-------------|
| `null` | Represents absence of value |
| `void` | Represents no return value |
| `never` | Represents function that never returns |

---

## Compound Types

### Arrays

Arrays are homogeneous, fixed-size collections:

```nyx
let numbers: [int] = [1, 2, 3, 4, 5];
let fixed: [i32; 4] = [1, 2, 3, 4];  # Fixed-size array
```

**Type Notation:** `T[n]` or `[T]`

### Slices

Slices are dynamically-sized views into arrays:

```nyx
let arr = [1, 2, 3, 4, 5];
let slice = arr[1:4];  # Elements at index 1, 2, 3
```

**Type Notation:** `&[T]`

### Objects/Hashes

Objects are key-value collections with string keys:

```nyx
let person = {
    name: "Alice",
    age: 30,
    active: true
};
```

**Type Notation:** `{ K: V }` or `{ key1: Type1, key2: Type2 }`

### Tuples

Fixed-size, heterogeneous collections:

```nyx
let point = (10, 20);
let triple = (1, "hello", true);
```

**Type Notation:** `(T1, T2, ...)`

### Functions

First-class function types:

```nyx
fn add(a: int, b: int) -> int {
    return a + b;
}

let fn_type: fn(int, int) -> int = add;
```

**Type Notation:** `fn(T1, T2, ...) -> T`

---

## Reference Types

### Immutable References

```nyx
let value = 42;
let ref: &int = &value;
```

**Type Notation:** `&T`

### Mutable References

```nyx
let mut_value = 10;
let mut_ref: &mut int = &mut mut_value;
*mut_ref = 20;  # Modify through mutable reference
```

**Type Notation:** `&mut T`

---

## User-Defined Types

### Classes

```nyx
class Point {
    x: int;
    y: int;
    
    fn new(self, x: int, y: int) {
        self.x = x;
        self.y = y;
    }
    
    fn distance(self, other: Point) -> int {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        return sqrt(dx * dx + dy * dy);
    }
}
```

### Structures (Records)

```nyx
struct Point {
    x: int,
    y: int,
}
```

### Enumerations

```nyx
enum Color {
    Red,
    Green,
    Blue,
    Custom(r: int, g: int, b: int)  # With associated data
}

let color = Color.Red;
let custom = Color.Custom(255, 128, 0);
```

### Type Aliases

```nyx
typealias IntList = [int];
typealias Matrix = [[f64]];
typealias Callback = fn(int) -> void;
```

---

## Generics

### Generic Functions

```nyx
fn first<T>(arr: [T]) -> T? {
    if (len(arr) > 0) {
        return arr[0];
    }
    return null;
}

let num = first([1, 2, 3]);      # T = int
let str = first(["a", "b"]);    # T = str
```

### Generic Classes

```nyx
class Box<T> {
    value: T;
    
    fn new(self, value: T) {
        self.value = value;
    }
    
    fn get(self) -> T {
        return self.value;
    }
}

let int_box = Box(42);
let str_box = Box("hello");
```

### Generic Constraints

```nyx
fn largest<T: Comparable>(arr: [T]) -> T? {
    # T must implement Comparable
}

fn print_debug<T: Display>(value: T) {
    print(value.debug());
}
```

---

## Type Inference

Nyx supports local type inference:

```nyx
let x = 10;              # Inferred as int
let s = "hello";         # Inferred as str
let arr = [1, 2, 3];     # Inferred as [int]
let fn_ptr = fn(x) { x + 1 };  # Inferred as fn(int) -> int
```

---

## Null Safety

### Nullable Types

```nyx
let nullable: int? = null;
let value: int? = 42;

# Null-coalescing
let result = nullable ?? 0;  # Use default if null
```

### Null-Checked Access

```nyx
# Safe navigation operator
let length = obj?.property?.length ?? 0;
```

---

## Type Predicates

Runtime type checking functions:

```nyx
type(value);        # Returns type name as string: "int", "string", "array", etc.
is_int(value);      # Is integer?
is_bool(value);     # Is boolean?
is_string(value);  # Is string?
is_array(value);   # Is array?
is_function(value); # Is function?
is_null(value);    # Is null?
```

---

## Type Conversion

### Explicit Conversion

```nyx
str(42);           # Integer to string: "42"
int("123");        # String to integer: 123
int(3.14);         # Float to integer: 3 (truncates)
float(42);         # Integer to float: 42.0
bool(1);           # Integer to boolean: true (non-zero is true)
```

### Type Coercion

Nyx performs implicit conversions in certain contexts:
- `int` to `f64` (widening)
- `str` concatenation is automatic

---

## Union Types

```nyx
# Value can be int or str
let id: int | str = "ABC123";
let numeric_id: int | str = 42;

# Pattern matching
match (id) {
    case v: int => print("Numeric: " + str(v));
    case v: str => print("String: " + v);
}
```

---

## Structural Types

### Interfaces

```nyx
interface Drawable {
    fn draw(self);
    fn area(self) -> f64;
}

class Circle implements Drawable {
    radius: f64;
    
    fn draw(self) { /* ... */ }
    fn area(self) -> f64 { 
        return 3.14159 * self.radius * self.radius;
    }
}
```

### Traits

```nyx
trait Comparable {
    fn compare(self, other: Self) -> int;
    # Returns: negative if self < other, 0 if equal, positive if greater
}

trait Printable {
    fn format(self) -> str;
}
---

## Advanced Types

### Function References

```nyx
let add = fn(a: int, b: int) -> int { a + b };
let ref: fn(int, int) -> int = add;
```

### Closures

```nyx
let closure = |x| x * 2;
let captured = 10;
let closure_with_capture = |x| x + captured;
```

### Result Types

```nyx
# Representing success/failure
enum Result<T, E> {
    Ok(T),
    Err(E)
}

fn divide(a: int, b: int) -> Result<int, str> {
    if (b == 0) {
        return Result.Err("Division by zero");
    }
    return Result.Ok(a / b);
}
```

### Option Types

```nyx
# Explicit optional handling
enum Option<T> {
    Some(T),
    None
}

fn find(items: [int], target: int) -> Option<int> {
    for (i, v in items) {
        if (v == target) {
            return Option.Some(i);
        }
    }
    return Option.None;
}
```

---

## Type System Properties

### Soundness

Nyx's type system is designed with formal soundness guarantees:

1. **Progress**: A well-typed expression is never stuck
2. **Preservation**: Evaluation preserves types
3. **Substitution**: Subtyping respects structural rules

### Type Safety

- No arbitrary pointer arithmetic
- Bounds-checked array access
- No use-after-free (via ownership system)
- No data races (via concurrency controls)

---

## Built-in Type Functions

| Function | Description |
|----------|-------------|
| `type(x)` | Get runtime type name |
| `is_*` | Type predicates |
| `str(x)` | Convert to string |
| `int(x)` | Convert to integer |
| `float(x)` | Convert to float |
| `bool(x)` | Convert to boolean |

---

## Type Declaration Syntax Summary

```
Type          ::= PrimitiveType
               | CompoundType
               | ReferenceType
               | UserDefinedType
               | GenericType
               | UnionType
               | OptionType

PrimitiveType ::= "int" | "i8" | "i16" | "i32" | "i64"
               | "u8" | "u16" | "u32" | "u64"
               | "f32" | "f64" | "bool" | "char" | "str"
               | "null" | "void" | "never"

CompoundType  ::= "[" Type "]"
               | "{" (Type ":" Type)+ "}"
               | "(" (Type "," Type)* ")"

ReferenceType ::= "&" Type
               | "&mut" Type

GenericType   ::= Type "<" TypeList ">"

UnionType     ::= Type "|" Type

OptionType    ::= Type "?"
```
