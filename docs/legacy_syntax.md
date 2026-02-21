# Nyx Language Syntax Reference

## Overview

Nyx is a modern, statically-typed programming language with influences from Rust, Python, and JavaScript. This document provides comprehensive syntax documentation for the Nyx programming language.

**File Extension:** `.ny` (primary), `.nx` (legacy support)

**Version:** This document covers Nyx v4+ runtime

---

## Python-Style Syntax Support

Nyx now supports Python-style syntax in addition to its traditional C-like syntax. You can use either style in your code.

### Python-Style (Indentation-Based)
```nyx
# If statement with colon and indentation
if x > 5:
    print("x is greater than 5")

# While loop
while counter < 10:
    print(counter)
    counter = counter + 1

# For-in loop
for item in array:
    print(item)

# Function definition
fn greet name:
    return "Hello, " + name

# Class definition
class Point:
    fn init(self, x, y):
        self.x = x
        self.y = y
```

### Traditional Nyx (Brace-Based)
```nyx
# If statement with braces
if (x > 5) {
    print("x is greater than 5");
}

# While loop
while (counter < 10) {
    print(counter);
    counter = counter + 1;
}

# For-in loop
for (item in array) {
    print(item);
}

# Function definition
fn greet(name) {
    return "Hello, " + name;
}

# Class definition
class Point {
    fn init(self, x, y) {
        self.x = x;
        self.y = y;
    }
}
```

### Key Differences

| Feature | Python-Style | Traditional Nyx |
|---------|--------------|-----------------|
| Condition | `if x > 5:` | `if (x > 5) {` |
| Block start | Colon (`:`) | Brace (`{`) |
| Block structure | Indentation | Braces (`{}`) |
| Semicolons | Optional | Required |

---

## Comments

Nyx uses `#` for single-line comments, similar to Python.

```nyx
# This is a single-line comment
let x = 10;  # Inline comment
```

---

## Identifiers

Identifiers follow standard naming conventions:

- Start with a letter (`a-z`, `A-Z`) or underscore (`_`)
- Continue with letters, digits (`0-9`), or underscores
- Are case-sensitive

```nyx
let foo = 1;
let _private = 2;
let camelCase = 3;
let snake_case = 4;
let UPPER_CASE = 5;
```

---

## Keywords

The following reserved keywords cannot be used as identifiers:

| Category | Keywords |
|----------|----------|
| **Declaration** | `fn`, `let`, `class`, `module`, `typealias` |
| **Control Flow** | `if`, `else`, `switch`, `case`, `default`, `while`, `for`, `in`, `break`, `continue`, `return` |
| **Error Handling** | `try`, `except`, `finally`, `raise`, `throw` |
| **Object-Oriented** | `new`, `self`, `super` |
| **Concurrency** | `async`, `await`, `yield` |
| **Special** | `null`, `true`, `false`, `pass`, `with`, `assert`, `import`, `from`, `as` |

---

## Literals

### Integer Literals

```nyx
let decimal = 42;
let hex = 0xFF;        # 255
let octal = 0o77;      # 63
let binary = 0b1010;   # 10
```

### Float Literals

```nyx
let float = 3.14;
let scientific = 1e10;
let negative = -3.14;
```

### String Literals

```nyx
let single = 'hello';
let double = "world";
let concat = "hello" + " " + "world";
```

### Boolean Literals

```nyx
let yes = true;
let no = false;
```

### Null Literal

```nyx
let nothing = null;
```

### Array Literals

```nyx
let numbers = [1, 2, 3, 4, 5];
let mixed = [1, "two", true, null];
let nested = [[1, 2], [3, 4]];
```

### Object/Hash Literals

```nyx
let point = { x: 10, y: 20 };
let with_strings = { "key": "value", name: "Nyx" };
let nested = { outer: { inner: 42 } };
```

### Array Comprehensions

```nyx
# Single-variable comprehension
let squares = [x * x for x in range(10)];

# Dual-variable (index, value)
let indexed = [i * v for i, v in arr];

# With condition
let evens = [x for x in range(10) if x % 2 == 0];
```

---

## Operators

### Arithmetic Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `+` | Addition | `a + b` |
| `-` | Subtraction | `a - b` |
| `*` | Multiplication | `a * b` |
| `/` | Division | `a / b` |
| `%` | Modulo | `a % b` |
| `**` | Power/Exponent | `a ** b` |
| `//` | Floor Division | `a // b` |

### Assignment Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` | Simple assignment | `x = 10` |
| `+=` | Add and assign | `x += 5` |
| `-=` | Subtract and assign | `x -= 5` |
| `*=` | Multiply and assign | `x *= 5` |
| `/=` | Divide and assign | `x /= 5` |
| `%=` | Modulo and assign | `x %= 5` |
| `//=` | Floor divide and assign | `x //= 5` |

### Comparison Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equal | `a == b` |
| `!=` | Not equal | `a != b` |
| `<` | Less than | `a < b` |
| `>` | Greater than | `a > b` |
| `<=` | Less than or equal | `a <= b` |
| `>=` | Greater than or equal | `a >= b` |

### Logical Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `&&` | Logical AND | `a && b` |
| `||` | Logical OR | `a \|\| b` |
| `!` | Logical NOT | `!a` |

### Null-Coalescing Operator

```nyx
let value = nullable ?? "default";
```

### Bitwise Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `&` | Bitwise AND | `a & b` |
| `\|` | Bitwise OR | `a \| b` |
| `^` | Bitwise XOR | `a ^ b` |
| `~` | Bitwise NOT | `~a` |
| `<<` | Left shift | `a << b` |
| `>>` | Right shift | `a >> b` |

### Unary Prefix Operators

```nyx
let negative = -5;
let negated = !true;
let bitnot = ~15;
```

---

## Statements

### Variable Declaration

```nyx
let x = 10;
let name = "Nyx";
let arr = [1, 2, 3];
let obj = { key: "value" };
```

### Expression Statement

```nyx
1 + 2;
"hello";
print("world");
```

### Return Statement

```nyx
fn add(a, b) {
    return a + b;
}

fn implicit() {
    42;  # Returns 42 at top level
}
```

### Block Statement

```nyx
{
    let x = 1;
    let y = 2;
    x + y
}
```

---

## Control Flow

### If-Else Statement

```nyx
if (condition) {
    # code
} else if (other_condition) {
    # code
} else {
    # code
}
```

### Switch Statement

```nyx
switch (value) {
    case 1: {
        print("one");
    }
    case 2: {
        print("two");
    }
    default: {
        print("other");
    }
}
```

### While Loop

```nyx
while (condition) {
    # body
}

let i = 0;
while (i < 10) {
    print(i);
    i = i + 1;
}
```

### For Loop (Traditional)

```nyx
for (let i = 0; i < 10; i = i + 1) {
    print(i);
}
```

### For-In Loop

```nyx
# Iterate over array
for (item in array) {
    print(item);
}

# Iterate with index
for (i, item in array) {
    print(i, item);
}

# Iterate over object keys
for (key in object) {
    print(key, object[key]);
}

# Iterate with key-value
for (k, v in object) {
    print(k, v);
}
```

### Loop Control

```nyx
break;      # Exit loop immediately
continue;   # Skip to next iteration
```

---

## Functions

### Function Declaration

```nyx
fn name(param1, param2) {
    return param1 + param2;
}

# With default parameters
fn greet(name, greeting = "Hello") {
    return greeting + ", " + name;
}
```

### Function Call

```nyx
let result = add(1, 2);
let greeting = greet("World");
let with_default = greet("Nyx", "Hi");
```

### Anonymous Functions (Closures)

```nyx
let add = fn(a, b) {
    return a + b;
};

let apply = fn(f, x, y) {
    return f(x, y);
};
```

### Arrow Functions

```nyx
let add = (a, b) => a + b;
let square = (x) => x * x;
let greet = (name) => { 
    return "Hello, " + name; 
};
```

---

## Classes

### Class Declaration

```nyx
class Point {
    fn init(self, x, y) {
        self.x = x;
        self.y = y;
    }
    
    fn distance(self, other) {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        return sqrt(dx * dx + dy * dy);
    }
}
```

### Class Instantiation

```nyx
let p1 = Point(10, 20);
let p2 = Point(30, 40);
let dist = p1.distance(p2);
```

### Inheritance

```nyx
class Point3D extends Point {
    fn init(self, x, y, z) {
        super.init(x, y);
        self.z = z;
    }
    
    fn distance_3d(self, other) {
        let d2d = super.distance(other);
        let dz = self.z - other.z;
        return sqrt(d2d * d2d + dz * dz);
    }
}
```

---

## Modules

### Module Declaration

```nyx
module Math {
    fn add(a, b) {
        return a + b;
    }
    
    fn multiply(a, b) {
        return a * b;
    }
}
```

### Module Usage

```nyx
import "math.ny";

let sum = Math.add(1, 2);
let product = Math.multiply(3, 4);
```

---

## Imports

### Standard Import

```nyx
import "library.ny";
import "./relative/path.ny";
```

### From Import

```nyx
from "module.ny" import function1, function2;
from "module.ny" import { function1 as f1 };
```

### Builtin Packages

```nyx
import "nymath";     # Math: abs, min, max, clamp, pow, sum
import "nyarrays";  # Arrays: first, last, sum, enumerate
import "nyobjects";  # Objects: merge, get_or
import "nyjson";     # JSON: parse, stringify
import "nyhttp";     # HTTP: get, text, ok
```

---

## Error Handling

### Try-Catch

```nyx
try {
    let result = risky_operation();
    print(result);
} catch (error) {
    print("Error: " + error);
}
```

### Try-Catch-Finally

```nyx
try {
    open_file();
} catch (e) {
    print("Failed: " + e);
} finally {
    cleanup();
}
```

### Raise/Throw

```nyx
fn divide(a, b) {
    if (b == 0) {
        raise "Division by zero";
    }
    return a / b;
}
```

---

## Special Statements

### Assert

```nyx
assert(condition);
assert(x > 0, "x must be positive");
```

### With Statement (Context Manager)

```nyx
with (open_file("data.txt")) as file {
    let content = read(file);
    process(content);
}
```

### Pass Statement

```nyx
if (condition) {
    pass;  # Do nothing
}

fn empty() {
    pass;  # Empty function body
}
```

---

## Built-in Functions

### I/O

```nyx
print("Hello");      # Print to stdout
read("file.txt");    # Read file content
write("file.txt", content);  # Write to file
```

### Type Conversion

```nyx
str(42);           # "42"
int("123");        # 123
type(value);       # "int", "string", "array", etc.
```

### Type Predicates

```nyx
is_int(value);
is_bool(value);
is_string(value);
is_array(value);
is_function(value);
is_null(value);
```

### Collections

```nyx
len(arr);         # Array/Object length
push(arr, value); # Add to array
pop(arr);         # Remove last element
keys(obj);        # Get object keys
values(obj);      # Get object values
items(obj);       # Get key-value pairs
has(obj, key);    # Check if key exists
```

### Numeric

```nyx
abs(-5);          # 5
min(1, 2);        # 1
max(1, 2);        # 2
clamp(5, 0, 10); # 5
sum([1, 2, 3]);   # 6
range(10);        # [0,1,2,3,4,5,6,7,8,9]
range(5, 10);     # [5,6,7,8,9]
range(0, 10, 2);  # [0,2,4,6,8]
```

### Other

```nyx
argc();           # Argument count
argv(index);      # Get argument
lang_version();   # Get language version
```

---

## Concurrency

### Async Function

```nyx
async fn fetch_data(url) {
    let response = await http_get(url);
    return response;
}
```

### Await Expression

```nyx
let data = await fetch_data("https://api.example.com");
```

### Yield

```nyx
fn generator() {
    yield 1;
    yield 2;
    yield 3;
}
```

---

## Syntax Summary

### Precedence (Lowest to Highest)

| Precedence | Operators |
|------------|-----------|
| 1 (Lowest) | `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `//=` |
| 2 | `yield` |
| 3 | `&&`, `\|\|` |
| 4 | `==`, `!=` |
| 5 | `<`, `>`, `<=`, `>=` |
| 6 | `+`, `-`, `\|`, `^` |
| 7 | `*`, `/`, `%`, `//`, `&`, `<<`, `>>` |
| 8 (Highest) | `!`, `-` (unary), `~` |

### Statement vs Expression

- **Statements** perform actions but don't produce values (except at top-level)
- **Expressions** produce values and can be used wherever values are expected
- Block `{ }` is an expression that evaluates to the last statement's value

---

## Whitespace and Semicolons

- Statements typically end with `;`
- Block forms (`if`, `while`, `for`, `fn`, `class`, `module`, `try/catch`) do NOT require semicolons
- Whitespace is ignored except as a token separator
- The lexer treats `#` as starting a comment that extends to end of line
