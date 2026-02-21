# Nyx Minimal Syntax - Ultra-Concise Programming

## Overview

Nyx Minimal is a new ultra-concise syntax for Nyx that dramatically reduces lines of code while maintaining performance. It removes C-style braces and introduces implicit patterns.

## Design Goals

1. **Reduce LOC**: 50-70% fewer lines than traditional syntax
2. **Reduce file size**: Shorter keywords, implicit returns, less punctuation
3. **Increase speed**: Simpler parser, fewer tokens, direct expressions

## Syntax Comparison

### Function Definitions

**Traditional Nyx (C-style):**
```
nyx
fn add(a, b) {
    return a + b;
}
```

**Traditional Nyx (Python-style):**
```
nyx
def add(a, b):
    return a + b
```

**Nyx Minimal:**
```
nyx
add a b = a + b
```

### Variable Declarations

**Traditional:**
```
nyx
let x = 10;
let name = "Nyx";
```

**Minimal:**
```
nyx
x := 10
name := "Nyx"
# Or even: x = 10 (type inferred)
```

### If Statements

**Traditional:**
```
nyx
if (x > 5) {
    print("x is greater than 5");
} else {
    print("x is less than or equal to 5");
}
```

**Minimal:**
```
nyx
if x > 5 
    print "x is greater than 5"
else 
    print "x is less than or equal to 5"
```

### While Loops

**Traditional:**
```
nyx
while (x < 10) {
    x = x + 1;
}
```

**Minimal:**
```
nyx
while x < 10 
    x += 1
```

### For Loops

**Traditional:**
```
nyx
for (item in array) {
    print(item);
}
```

**Minimal:**
```
nyx
for item in array 
    print item
```

### Classes

**Traditional:**
```
nyx
class Point {
    fn init(self, x, y) {
        self.x = x;
        self.y = y;
    }
    
    fn distance(self, other) {
        return sqrt(self.x - other.x) ** 2 + (self.y - other.y) ** 2;
    }
}
```

**Minimal:**
```
nyx
class Point:
    x y
    
    distance self other = 
        sqrt (self.x - other.x) ^ 2 + (self.y - other.y) ^ 2
```

### Arrays

**Traditional:**
```
nyx
let numbers = [1, 2, 3, 4, 5];
let squared = [x * x for x in numbers];
```

**Minimal:**
```nyx
numbers := [1, 2, 3, 4, 5]
squared := [x * x for x]
```

### Objects

**Traditional:**
```nyx
let person = {
    name: "John",
    age: 30,
    active: true
};
```

**Minimal:**
```
nyx
person := { name: "John", age: 30, active: true }
# Or
person = { name: "John", age: 30 }
```

### Function Calls

**Traditional:**
```
nyx
let result = add(1, 2);
let greeting = greet("World", "Hello");
```

**Minimal:**
```
nyx
result = add 1 2
greeting = greet "World" "Hello"
```

### Pattern Matching

**Traditional:**
```
nyx
switch (value) {
    case 1: { print("one"); }
    case 2: { print("two"); }
    default: { print("other"); }
}
```

**Minimal:**
```
nyx
match value:
    1 => print "one"
    2 => print "two"
    _ => print "other"
```

## Key Differences from C-Style

| Feature | C-Style | Minimal |
|---------|---------|---------|
| Function | `fn add(a, b) { return a + b; }` | `add a b = a + b` |
| If | `if (cond) { ... }` | `if cond ...` |
| While | `while (cond) { ... }` | `while cond ...` |
| Return | `return expr;` | Implicit (last expr) |
| Let | `let x = 10;` | `x := 10` or `x = 10` |
| Semicolons | Required | Optional |
| Braces | Required | Not used |

## Performance Benefits

1. **Faster Lexing**: Fewer tokens to process
2. **Faster Parsing**: Simpler grammar, fewer rules
3. **Faster Execution**: Implicit returns avoid extra jumps
4. **Smaller AST**: Fewer nodes in the tree

## Backwards Compatibility

Nyx Minimal coexists with existing Nyx syntax. The lexer detects the style:
- Lines ending with `=` followed by expression = function definition
- `:=` for new variables
- No braces = minimal style
- Indentation or keywords determine blocks

## Examples

### Hello World
```
nyx
# Traditional: 3 lines
fn main() {
    print("Hello, World!");
}

# Minimal: 1 line
print "Hello, World!"
```

### Fibonacci
```
nyx
# Traditional: ~15 lines
fn fib(n) {
    if (n <= 1) {
        return n;
    }
    return fib(n - 1) + fib(n - 2);
}

# Minimal: ~5 lines
fib n = if n <= 1 then n else fib (n-1) + fib (n-2)
```

### Calculator
```
nyx
# Minimal calculator - ~20 lines
add a b = a + b
sub a b = a - b
mul a b = a * b
div a b = if b == 0 then "Error" else a / b

calc op a b = 
    match op
        "+" => add a b
        "-" => sub a b
        "*" => mul a b
        "/" => div a b
        _ => "Invalid op"

print (calc "+" 10 5)  # 15
print (calc "/" 10 0)   # Error
```

## Implementation Notes

The minimal syntax requires:
1. Lexer updates for new tokens (`:=`, `=>`, `->`)
2. Parser updates for implicit patterns
3. AST changes for implicit returns
4. Interpreter handling of minimal expressions
