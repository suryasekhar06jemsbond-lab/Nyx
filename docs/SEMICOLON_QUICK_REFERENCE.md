# Nyx Semicolon Quick Reference

## TL;DR ✨

**Semicolons are OPTIONAL in Nyx. Both styles work perfectly!**

```nyx
// ✅ With semicolons
let x = 5;
let y = 10;

// ✅ Without semicolons  
let x = 5
let y = 10

// ✅ Mixed (your choice!)
let x = 5;
let y = 10
```

## Examples at a Glance

### Variables
```nyx
let name = "Alice";     // ✅ Works
let name = "Alice"      // ✅ Works
```

### Functions
```nyx
fn add(a, b) {
    return a + b;       // ✅ Works
}

fn add(a, b) {
    return a + b        // ✅ Works
}
```

### Expressions
```nyx
print("Hello");         // ✅ Works
print("Hello")          // ✅ Works

let x = 1 + 2;          // ✅ Works
let x = 1 + 2           // ✅ Works
```

### Control Flow
```nyx
if (condition) {
    doSomething();      // ✅ Works
}

if (condition) {
    doSomething()       // ✅ Works
}
```

## When Semicolons ARE Required

Only in **C-style for loops**:
```nyx
for (let i = 0; i < 10; i = i + 1) {  // Semicolons required in header
    print(i)                           // Semicolon optional in body
}
```

## Style Guide Recommendation

Choose one style per project and be consistent:

**Style A - Explicit** (C, Java, JavaScript with semicolons)
```nyx
let x = 5;
let y = 10;
let result = x + y;
print(result);
```

**Style B - Implicit** (Python, JavaScript without semicolons)
```nyx
let x = 5
let y = 10
let result = x + y
print(result)
```

**Style C - Pragmatic** (Use semicolons for complex statements)
```nyx
let x = 5
let y = 10

// Complex multi-line
let result = (x * 2) + 
             (y * 3);

print(result)
```

## Testing

Run the test suite to see all patterns in action:
```bash
python nyx_runtime.py tests/test_semicolon_optional.ny
```

## Implementation

This feature is built into the Nyx parser at [src/parser.py](../src/parser.py):
- `parse_let_statement()` - Optional semicolon after variable declaration
- `parse_return_statement()` - Optional semicolon after return
- `parse_expression_statement()` - Optional semicolon after expressions

## Summary

| Statement Type | Semicolon Required? | Example |
|---------------|---------------------|---------|
| Variable declaration | ❌ No | `let x = 5` or `let x = 5;` |
| Function definition | ❌ No | `fn f() { return 1 }` or `fn f() { return 1; }` |
| Return statement | ❌ No | `return x` or `return x;` |
| Expression | ❌ No | `print(x)` or `print(x);` |
| For loop header | ✅ Yes | `for (init; cond; incr)` |
| Multi-statement line | ✅ Yes | `let x = 1; let y = 2;` |

**Your code, your style. Nyx adapts to you.** 🚀
