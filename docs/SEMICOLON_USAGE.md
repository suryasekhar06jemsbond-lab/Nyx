# Semicolon Usage in Nyx

## Overview

**Semicolons are OPTIONAL in Nyx.** The language parser accepts both styles seamlessly, allowing developers to choose their preferred syntax style.

## Supported Syntax Styles

### ✅ With Semicolons (Explicit Style)
```nyx
let x = 5;
let y = 10;
let result = x + y;
print(result);
```

### ✅ Without Semicolons (Implicit Style)
```nyx
let x = 5
let y = 10
let result = x + y
print(result)
```

### ✅ Mixed Style
```nyx
let x = 5;
let y = 10
let result = x + y;
print(result)
```

## Implementation Details

### Parser Behavior

The Nyx parser in `src/parser.py` implements optional semicolon support through conditional checks:

1. **Let Statements** (`parse_let_statement`)
```python
if self.peek_token_is(TokenType.SEMICOLON):
    self.next_token()
```

2. **Return Statements** (`parse_return_statement`)
```python
if self.peek_token_is(TokenType.SEMICOLON):
    self.next_token()
```

3. **Expression Statements** (`parse_expression_statement`)
```python
if self.peek_token_is(TokenType.SEMICOLON):
    self.next_token()
```

### How It Works

- **Semicolons are checked but NOT required**
- If a semicolon is present, the parser consumes it
- If a semicolon is absent, the parser continues normally
- Statement boundaries are detected through:
  - Newlines (implicit termination)
  - Next token type (keyword-based detection)
  - Block delimiters (`{`, `}`)

### Lexer Support

The lexer (`src/lexer.py`) tokenizes semicolons as `TokenType.SEMICOLON` but doesn't enforce their presence:

```python
# Whitespace and comment skipping includes newlines
while self.ch in (" ", "\t", "\r", "\n"):
    self._read_char()
```

Newline characters are treated as whitespace, allowing natural statement separation without semicolons.

## Examples

### Variable Declarations
```nyx
# With semicolons
let name = "Alice";
let age = 30;
let active = true;

# Without semicolons
let name = "Alice"
let age = 30
let active = true
```

### Function Definitions
```nyx
# With semicolons
fn add(a, b) {
    return a + b;
}

# Without semicolons
fn add(a, b) {
    return a + b
}

# Mixed
fn multiply(a, b) {
    let result = a * b;
    return result
}
```

### Control Flow
```nyx
# With semicolons
if (x > 10) {
    print("Large");
} else {
    print("Small");
}

# Without semicolons
if (x > 10) {
    print("Large")
} else {
    print("Small")
}
```

### Loops
```nyx
# With semicolons
for (let i = 0; i < 5; i = i + 1) {
    print(i);
}

# Without semicolons (note: for loop header still uses semicolons for C-style syntax)
for (let i = 0; i < 5; i = i + 1) {
    print(i)
}
```

### Arrays and Hashes
```nyx
# With semicolons
let numbers = [1, 2, 3, 4, 5];
let person = {"name": "Bob", "age": 25};

# Without semicolons
let numbers = [1, 2, 3, 4, 5]
let person = {"name": "Bob", "age": 25}
```

## Style Recommendations

### When to Use Semicolons

1. **C-style for loops** - Required in loop headers: `for (init; condition; increment)`
2. **Multiple statements on one line** - Use semicolons for clarity: `let x = 1; let y = 2`
3. **Team preference** - Follow your project's style guide

### When to Omit Semicolons

1. **Python/JavaScript-like style** - For cleaner, more concise code
2. **Functional programming** - Expression-heavy code reads better without semicolons
3. **DSL-style code** - Domain-specific language patterns benefit from minimal punctuation

## Compatibility

This feature is fully compatible with:
- **All Nyx versions** - The parser has always supported optional semicolons
- **DFAS modules** - The Dynamic Field Arithmetic System uses optional semicolons throughout
- **All standard library code** - Both styles work in all contexts

## Testing

Run the test file to verify both syntax styles work:

```bash
python nyx_runtime.py test_semicolons.ny
```

## Technical Notes

### Expression Parsing

The expression parser uses semicolons as **terminators**, not **separators**:

```python
while not self.peek_token_is(TokenType.SEMICOLON) and precedence < self.peek_precedence():
    # Continue parsing expression
```

This means:
- Semicolons **stop** expression parsing
- Newlines are treated as whitespace
- Statement boundaries are inferred from context

### Empty Statements

Empty semicolons are allowed and ignored:

```python
if token_type == TokenType.SEMICOLON:
    return None  # Skip empty statements
```

This allows code like:
```nyx
let x = 5;;  # Double semicolon is valid
;;           # Empty statements are ignored
```

## Conclusion

**Nyx provides complete flexibility for semicolon usage:**
- ✅ Use semicolons → Works perfectly
- ✅ Omit semicolons → Works perfectly
- ✅ Mix both styles → Works perfectly

Choose the style that fits your project and coding preferences. The Nyx parser handles all variations seamlessly.
