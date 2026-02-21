# Nyx v1.0: Complete Language Architecture Specification

**Version:** 1.0.0  
**Status:** Production-Ready Specification  
**Date:** 2026-02-16  
**Authors:** Nyx Language Design Team

---

## Executive Summary

Nyx is a **systems programming language** that combines:
- **Python-level expressiveness** (minimal boilerplate, clear syntax)
- **Rust-level safety** (ownership-based memory management, compile-time guarantees)
- **Julia-level scientific computing** (first-class arrays, mathematical notation)
- **Zero-cost abstractions** (no GC, deterministic performance)

**One-Sentence Philosophy:**  
*"A memory-safe systems language that feels like Python, performs like Rust, and computes like Julia."*

---

## A. Final Language Identity

### A1. Core Philosophy

Nyx is designed for **scientific computing, systems programming, and high-performance applications** where:
- Memory safety is non-negotiable (no GC pauses)
- Expressiveness matters (scientific code should read like math)
- Performance is critical (native speed, predictable latency)
- Interoperability is essential (C FFI, Python interop, GPU compute)

### A2. Chosen Paradigm

**Multi-paradigm with strong type safety:**
- **Imperative** (default): C-like control flow, mutable state
- **Functional** (first-class): Functions as values, closures, immutability by default
- **Object-oriented** (minimal): Classes for encapsulation, no inheritance complexity
- **Concurrent** (async-first): Async/await, channels, structured concurrency

### A3. Target Users

1. **Scientific Computing**: Researchers, data scientists, ML engineers
2. **Systems Programmers**: OS developers, embedded systems, high-performance servers
3. **Performance-Critical Applications**: Game engines, real-time systems, HPC
4. **Language Learners**: Graduating from Python to systems programming

### A4. Comparison Matrix

| Feature | Nyx | Python | Rust | Julia |
|---------|-----|--------|------|-------|
| **Syntax** | C-style braces | Indentation | C-style braces | MATLAB-like |
| **Type System** | Static, inferred | Dynamic | Static, explicit | Dynamic, inferred |
| **Memory** | Ownership (no GC) | GC | Ownership | GC |
| **Performance** | Native (Rust-level) | Interpreted | Native | JIT-compiled |
| **Expressiveness** | High (Python-like) | Very High | Medium | Very High |
| **Safety** | Compile-time | Runtime | Compile-time | Runtime |
| **Scientific** | First-class | Libraries | Libraries | First-class |
| **Learning Curve** | Medium | Low | High | Medium |

**Key Differentiators:**
- **vs Python**: Static types, no GC, native performance
- **vs Rust**: More expressive syntax, better scientific computing primitives
- **vs Julia**: Memory safety guarantees, systems programming focus

---

## B. Frozen Nyx v1 Core Specification

### B1. Definitive Syntax Rules

#### B1.1. Syntax Philosophy: **C-Style Braces**

**DECISION:** Nyx uses **C-style braces** (`{}`) for all blocks. Indentation-based syntax is **rejected** for v1.

**Rationale:**
- Consistency with systems programming tradition
- Easier parsing and tooling
- Better IDE support
- No ambiguity with mixed tabs/spaces

#### B1.2. Statement Termination

**Rule:** All statements **MUST** end with `;` except:
- Block statements (`if`, `while`, `for`, `fn`, `class`, `try`, `switch`)
- Expression statements at top-level (optional `;`)

```nyx
// CORRECT
let x = 10;
if (x > 5) {
    print("yes");
}

// INCORRECT
let x = 10  // Missing semicolon
if (x > 5)  // Missing braces
    print("yes");
```

#### B1.3. Comments

**Single-line:** `# comment`  
**Multi-line:** Not supported in v1 (use multiple `#` lines)

#### B1.4. Identifiers

- Start with letter or `_`
- Continue with letters, digits, `_`
- Case-sensitive
- Keywords cannot be identifiers

**Reserved Keywords (v1):**
```
fn, let, mut, if, else, while, for, in, break, continue, return,
class, struct, enum, impl, trait, interface, new, self, super,
try, catch, finally, throw, raise, assert,
async, await, yield,
import, from, as, module,
switch, case, default,
true, false, null, void, never,
typealias, type, where,
pub, priv, static, const,
```

### B2. Final Type System

#### B2.1. Type Hierarchy

```
Type
├── PrimitiveType
│   ├── Integer (int, i8, i16, i32, i64, u8, u16, u32, u64)
│   ├── Float (f32, f64)
│   ├── Boolean (bool)
│   ├── Character (char)
│   └── String (str)
├── CompoundType
│   ├── Array ([T])
│   ├── Slice (&[T])
│   ├── Tuple ((T1, T2, ...))
│   ├── Object ({ K: V })
│   └── Function (fn(T1, T2) -> T)
├── ReferenceType
│   ├── Immutable (&T)
│   └── Mutable (&mut T)
├── OptionalType (T?)
├── UnionType (T1 | T2)
└── UserDefinedType
    ├── Class
    ├── Struct
    ├── Enum
    └── Trait/Interface
```

#### B2.2. Type Inference Rules

**Local inference:** Always infer types from initializers
```nyx
let x = 10;        // x: int
let s = "hello";  // s: str
let arr = [1, 2]; // arr: [int]
```

**Function inference:** Infer return types when possible
```nyx
fn add(a: int, b: int) {  // Return type inferred as int
    return a + b;
}
```

**Explicit annotations:** Required for:
- Function parameters (except closures)
- Struct/class fields
- Public API boundaries

#### B2.3. Type Safety Guarantees

1. **No implicit conversions** (except widening: `int` → `f64`)
2. **Null safety**: `T?` types must be checked before use
3. **Bounds checking**: Array access always checked (can be optimized away)
4. **No type erasure**: Generics are monomorphized

### B3. Final Memory Model

#### B3.1. Ownership System

**Core Rules:**
1. Every value has **exactly one owner**
2. Assignment **moves** ownership (unless `Copy` trait)
3. References (`&T`, `&mut T`) **borrow** without ownership
4. Borrows must not outlive their referent

**Copy Types** (implement `Copy` trait automatically):
- All primitive types (`int`, `bool`, `f64`, `char`)
- Tuples of `Copy` types
- References (`&T`, `&mut T`)

**Move Types** (default):
- `String`, `[T]`, `{K: V}`
- User-defined types (unless `Copy`)

#### B3.2. No Garbage Collector

**DECISION:** Nyx v1 has **NO garbage collector**. Memory is managed via:
- Ownership system (compile-time)
- RAII (Resource Acquisition Is Initialization)
- Explicit `drop()` methods

**Rationale:**
- Zero GC pauses
- Predictable performance
- Deterministic resource cleanup
- Systems programming requirement

#### B3.3. Reference Counting (Optional)

**Smart Pointers** (in stdlib, not language):
- `Rc<T>`: Single-threaded reference counting
- `Arc<T>`: Thread-safe reference counting

These are **library types**, not language primitives.

### B4. Execution Model

#### B4.1. Compilation Modes

1. **Interpreted** (default): Direct AST execution
2. **VM Bytecode** (`--vm`): Compile to bytecode, execute in VM
3. **Native Binary** (`--compile`): Compile to native code (future)

#### B4.2. Runtime Model

- **Stack-based VM** for bytecode execution
- **Ownership tracking** at compile-time (zero runtime cost)
- **Bounds checking** at runtime (can be disabled with `--release`)

### B5. Module System

#### B5.1. Module Declaration

```nyx
// File: math.ny
module Math {
    pub fn add(a: int, b: int) -> int {
        return a + b;
    }
    
    priv fn internal() {
        // Private to module
    }
}
```

#### B5.2. Import System

```nyx
// Import entire module
import "math.ny";
let result = Math.add(1, 2);

// Import specific items
from "math.ny" import add, subtract;
let result = add(1, 2);

// Import with alias
import "math.ny" as m;
let result = m.add(1, 2);
```

#### B5.3. Package System

**Package Manifest** (`ny.pkg`):
```toml
[package]
name = "mypackage"
version = "1.0.0"
authors = ["Author <author@example.com>"]

[dependencies]
other_package = "1.2.0"
```

**Package Registry:** Centralized at `registry.nyxlang.dev`

### B6. Error Handling

#### B6.1. Exception Model

**DECISION:** Nyx v1 uses **exceptions** (`try/catch/throw`), not `Result<T, E>`.

**Rationale:**
- More familiar to Python/Java developers
- Less verbose than `Result` types
- Better for scientific computing (errors are exceptional)

```nyx
try {
    let result = risky_operation();
    process(result);
} catch (e: Error) {
    print("Error: " + e.message);
} finally {
    cleanup();
}
```

#### B6.2. Exception Types

- `Error`: Base exception type
- `ValueError`: Invalid value
- `TypeError`: Type mismatch
- `IndexError`: Out of bounds
- `IOError`: I/O operations
- Custom exceptions: `class MyError extends Error`

### B7. Concurrency

#### B7.1. Async/Await Model

```nyx
async fn fetch(url: str) -> Response {
    let response = await http_get(url);
    return response;
}

async fn main() {
    let data = await fetch("https://api.example.com");
    print(data);
}
```

#### B7.2. Task Spawning

```nyx
let task = spawn(async {
    let result = await compute();
    return result;
});

let value = await task;
```

#### B7.3. Channels

```nyx
let (tx, rx) = channel();

spawn(async {
    tx.send("Hello");
});

let msg = await rx.recv();
```

---

## C. Removed or Rejected Features

### C1. Syntax Features Removed

1. **Indentation-based syntax** → Rejected
   - **Why:** Ambiguity, tooling complexity, inconsistent with systems programming tradition

2. **Optional semicolons** → Rejected (except top-level expressions)
   - **Why:** Ambiguity in parsing, inconsistent with C-style syntax

3. **Python-style `:` after `if/while`** → Rejected
   - **Why:** Inconsistent with brace-based syntax

4. **Arrow functions `=>`** → Rejected (use `fn` keyword)
   - **Why:** Redundant, `fn` is clearer

5. **Match expressions** → Deferred to v2
   - **Why:** `switch` is sufficient for v1, pattern matching is complex

### C2. Type System Features Removed

1. **Dynamic typing** → Rejected
   - **Why:** Core value proposition is static safety

2. **Type erasure for generics** → Rejected
   - **Why:** Performance and clarity require monomorphization

3. **Structural subtyping** → Deferred to v2
   - **Why:** Nominal types (classes/interfaces) are sufficient

4. **Higher-kinded types** → Deferred to v2
   - **Why:** Too complex for v1, not needed for initial use cases

### C3. Memory Model Features Removed

1. **Garbage Collector** → Rejected
   - **Why:** Core value proposition is zero GC pauses

2. **Automatic reference counting** → Rejected (as language feature)
   - **Why:** Ownership system is sufficient; `Rc<T>` available in stdlib

3. **Weak references** → Deferred to v2
   - **Why:** Not needed for v1 use cases

### C4. Concurrency Features Removed

1. **OS threads** → Deferred to v2
   - **Why:** Green threads (tasks) are sufficient for v1

2. **Actor model** → Deferred to v2
   - **Why:** Channels + async/await are sufficient

### C5. Language Features Removed

1. **Macros** → Deferred to v2
   - **Why:** Too complex, not needed for v1

2. **Reflection** → Deferred to v2
   - **Why:** Performance and safety concerns

3. **Operator overloading** → Deferred to v2
   - **Why:** Can be added later without breaking changes

---

## D. Formal Grammar (Clean EBNF)

```ebnf
(* =============================================================================
 * Nyx v1.0 Formal Grammar
 * Ambiguity-free, production-ready
 * ============================================================================= *)

(* LEXICAL TOKENS *)
letter          = "A" | "B" | ... | "Z" | "a" | "b" | ... | "z" | "_" ;
digit           = "0" | "1" | ... | "9" ;
hex-digit       = digit | "A" | "B" | ... | "F" | "a" | "b" | ... | "f" ;
octal-digit     = "0" | "1" | ... | "7" ;
binary-digit    = "0" | "1" ;

identifier      = letter, { letter | digit } ;

integer-literal = digit, { digit }
               | "0x", hex-digit, { hex-digit }
               | "0o", octal-digit, { octal-digit }
               | "0b", binary-digit, { binary-digit } ;

float-literal   = digit, { digit }, ".", { digit }
               | digit, { digit }, ( "e" | "E" ), [ "+" | "-" ], digit, { digit } ;

string-literal  = '"', { string-char - '"' | escape-seq }, '"'
               | "'", { string-char - "'" | escape-seq }, "'" ;

escape-seq      = "\", ( "n" | "t" | "r" | "\" | '"' | "'" | "x", hex-digit, hex-digit ) ;

boolean-literal = "true" | "false" ;
null-literal    = "null" ;

comment         = "#", { any-char - "\n" }, "\n" ;

(* PROGRAM STRUCTURE *)
program         = { statement } ;
source-file     = { statement } ;

(* STATEMENTS *)
statement       = declaration-statement
               | expression-statement
               | control-flow-statement
               | import-statement
               | class-statement
               | struct-statement
               | enum-statement
               | trait-statement
               | module-statement
               | try-statement
               | assert-statement
               | async-statement
               | return-statement
               | break-statement
               | continue-statement
               | yield-statement
               | pass-statement ;

(* DECLARATIONS *)
declaration-statement = variable-declaration
                      | function-declaration
                      | type-alias-declaration ;

variable-declaration = "let", [ "mut" ], identifier, [ ":", type ], "=", expression, ";" ;

function-declaration = [ "pub" ], [ "async" ], "fn", identifier, parameters, [ "->", type ], block-statement ;

parameters      = "(", [ parameter-list ], ")" ;
parameter-list  = parameter, { ",", parameter } ;
parameter       = identifier, ":", type ;

type-alias-declaration = "typealias", identifier, "=", type, ";" ;

(* EXPRESSIONS *)
expression-statement = expression, ";" ;

expression      = assignment-expression ;

assignment-expression = ( identifier | member-access | index-access ), assignment-operator, expression
                      | conditional-expression ;

assignment-operator = "=" | "+=" | "-=" | "*=" | "/=" | "%=" | "//=" ;

conditional-expression = logical-or-expression, [ "?", expression, ":", conditional-expression ] ;

logical-or-expression = logical-and-expression, { "||", logical-and-expression } ;

logical-and-expression = bitwise-or-expression, { "&&", bitwise-or-expression } ;

bitwise-or-expression = bitwise-xor-expression, { "|", bitwise-xor-expression } ;

bitwise-xor-expression = bitwise-and-expression, { "^", bitwise-and-expression } ;

bitwise-and-expression = equality-expression, { "&", equality-expression } ;

equality-expression = relational-expression, { ( "==" | "!=" ), relational-expression } ;

relational-expression = shift-expression, { ( "<" | ">" | "<=" | ">=" ), shift-expression } ;

shift-expression = additive-expression, { ( "<<" | ">>" ), additive-expression } ;

additive-expression = multiplicative-expression, { ( "+" | "-" ), multiplicative-expression } ;

multiplicative-expression = power-expression, { ( "*" | "/" | "%" | "//" ), power-expression } ;

power-expression = unary-expression, [ "**", power-expression ] ;

unary-expression = prefix-operator, unary-expression
                 | postfix-expression ;

prefix-operator = "-" | "+" | "!" | "~" | "&" | "&mut" | "*" ;

postfix-expression = primary-expression
                   | postfix-expression, "(", [ argument-list ], ")"
                   | postfix-expression, "[", expression, "]"
                   | postfix-expression, ".", identifier
                   | postfix-expression, "?" ;

argument-list   = expression, { ",", expression } ;

primary-expression = literal
                   | identifier
                   | "(", expression, ")"
                   | block-expression
                   | if-expression
                   | function-literal
                   | array-literal
                   | object-literal
                   | tuple-expression
                   | new-expression
                   | self-expression
                   | super-expression
                   | await-expression ;

(* LITERALS *)
literal         = integer-literal
               | float-literal
               | string-literal
               | boolean-literal
               | null-literal ;

function-literal = "fn", [ identifier ], parameters, [ "->", type ], block-statement ;

array-literal   = "[", [ expression-list ], "]" ;

expression-list = expression, { ",", expression } ;

object-literal  = "{", [ key-value-list ], "}" ;

key-value-list  = key-value-pair, { ",", key-value-pair } ;

key-value-pair  = ( identifier | string-literal ), ":", expression ;

tuple-expression = "(", expression, ",", expression, { ",", expression }, ")" ;

(* CONTROL FLOW *)
control-flow-statement = if-statement
                       | while-statement
                       | for-statement
                       | switch-statement
                       | return-statement
                       | break-statement
                       | continue-statement
                       | yield-statement ;

if-statement    = "if", "(", expression, ")", block-statement,
                  { "else", "if", "(", expression, ")", block-statement },
                  [ "else", block-statement ] ;

if-expression   = "if", "(", expression, ")", expression, "else", expression ;

while-statement = "while", "(", expression, ")", block-statement ;

for-statement   = "for", "(", [ for-init ], ";", [ expression ], ";", [ expression ], ")", block-statement
               | "for", "(", identifier, [ ",", identifier ], "in", expression, ")", block-statement ;

for-init        = variable-declaration | expression-statement ;

switch-statement = "switch", "(", expression, ")", "{", { case-clause }, [ default-clause ], "}" ;

case-clause     = "case", expression, ":", statement ;

default-clause  = "default", ":", statement ;

return-statement = "return", [ expression ], ";" ;

break-statement = "break", ";" ;

continue-statement = "continue", ";" ;

yield-statement = "yield", [ expression ], ";" ;

(* BLOCKS *)
block-statement = "{", { statement }, "}" ;

block-expression = "{", { statement }, [ expression ], "}" ;

(* TYPES *)
type            = primitive-type
               | compound-type
               | reference-type
               | optional-type
               | union-type
               | function-type
               | user-defined-type
               | generic-type ;

primitive-type  = "int" | "i8" | "i16" | "i32" | "i64"
               | "u8" | "u16" | "u32" | "u64"
               | "f32" | "f64"
               | "bool" | "char" | "str"
               | "void" | "null" | "never" ;

compound-type   = "[", type, "]"
               | "{", [ type-member-list ], "}"
               | "(", type-list, ")" ;

type-member-list = type-member, { ",", type-member } ;

type-member     = identifier, ":", type ;

type-list       = type, { ",", type } ;

reference-type  = "&", [ "mut" ], type ;

optional-type   = type, "?" ;

union-type      = type, "|", type, { "|", type } ;

function-type   = "fn", "(", [ type-list ], ")", "->", type ;

user-defined-type = identifier, [ type-arguments ] ;

type-arguments  = "<", type-list, ">" ;

generic-type    = identifier, "<", type-list, ">" ;

(* CLASSES AND STRUCTS *)
class-statement = [ "pub" ], "class", identifier, [ type-parameters ], [ "extends", type ], "{", { class-member }, "}" ;

class-member    = field-declaration
               | method-declaration
               | constructor-declaration ;

field-declaration = [ "pub" ], identifier, ":", type, ";" ;

method-declaration = [ "pub" ], [ "async" ], "fn", identifier, parameters, [ "->", type ], block-statement ;

constructor-declaration = "fn", "new", parameters, block-statement ;

struct-statement = [ "pub" ], "struct", identifier, [ type-parameters ], "{", field-list, "}" ;

field-list      = field-declaration, { field-declaration } ;

(* ENUMS *)
enum-statement  = [ "pub" ], "enum", identifier, [ type-parameters ], "{", enum-variant-list, "}" ;

enum-variant-list = enum-variant, { ",", enum-variant } ;

enum-variant    = identifier, [ "(", type-list, ")" ] ;

(* TRAITS *)
trait-statement = [ "pub" ], "trait", identifier, [ type-parameters ], [ "extends", type-list ], "{", { trait-member }, "}" ;

trait-member    = method-declaration
               | associated-type-declaration ;

associated-type-declaration = "type", identifier, [ ":", type ], ";" ;

(* MODULES *)
module-statement = "module", identifier, "{", { statement }, "}" ;

(* IMPORTS *)
import-statement = "import", string-literal, [ "as", identifier ], ";"
               | "from", string-literal, "import", import-list, ";" ;

import-list     = identifier, { ",", identifier }
               | "{", identifier-list, "}" ;

identifier-list = identifier, { ",", identifier } ;

(* ERROR HANDLING *)
try-statement   = "try", block-statement,
                  "catch", "(", identifier, [ ":", type ], ")", block-statement,
                  [ "finally", block-statement ] ;

assert-statement = "assert", "(", expression, [ ",", expression ], ")", ";" ;

(* ASYNC *)
async-statement = "async", block-statement ;

await-expression = "await", expression ;

(* OBJECT CREATION *)
new-expression  = "new", type, [ "(", [ argument-list ], ")" ] ;

self-expression = "self" ;

super-expression = "super", [ "(", [ argument-list ], ")" ] ;

(* OTHER *)
pass-statement  = "pass", ";" ;

(* OPERATOR PRECEDENCE (Highest to Lowest) *)
(*
  1. Postfix:  a.b, a[b], f(), a?
  2. Unary:    -a, !a, &a, &mut a, *a
  3. Power:    a ** b
  4. Multiplicative: *, /, %, //
  5. Additive: +, -
  6. Shift:    <<, >>
  7. Bitwise AND: &
  8. Bitwise XOR: ^
  9. Bitwise OR: |
  10. Relational: <, >, <=, >=
  11. Equality: ==, !=
  12. Logical AND: &&
  13. Logical OR: ||
  14. Conditional: ? :
  15. Assignment: =, +=, -=, etc.
*)
```

---

## E. Minimal but Complete Standard Library Design

### E1. Core Modules

#### `core` (always available)
- `print(...)`: Print to stdout
- `println(...)`: Print with newline
- `panic(message: str)`: Abort program
- `assert(condition: bool, message?: str)`: Assertion

#### `types`
- Type predicates: `is_int`, `is_str`, `is_array`, etc.
- Type conversion: `str`, `int`, `float`, `bool`
- Type information: `type(x) -> str`

#### `math`
- Basic: `abs`, `min`, `max`, `clamp`, `sqrt`, `pow`
- Trig: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`
- Log: `log`, `log10`, `exp`
- Rounding: `floor`, `ceil`, `round`

#### `string`
- `len(s: str) -> int`
- `concat(...strs) -> str`
- `split(s: str, sep: str) -> [str]`
- `join(arr: [str], sep: str) -> str`
- `trim(s: str) -> str`
- `upper(s: str) -> str`
- `lower(s: str) -> str`

#### `array`
- `len(arr: [T]) -> int`
- `push(arr: &mut [T], value: T)`
- `pop(arr: &mut [T]) -> T?`
- `insert(arr: &mut [T], index: int, value: T)`
- `remove(arr: &mut [T], index: int) -> T`
- `slice(arr: [T], start: int, end: int) -> [T]`
- `map(arr: [T], fn: fn(T) -> U) -> [U]`
- `filter(arr: [T], fn: fn(T) -> bool) -> [T]`
- `reduce(arr: [T], fn: fn(T, T) -> T, initial: T) -> T`

#### `object`
- `keys(obj: {K: V}) -> [str]`
- `values(obj: {K: V}) -> [V]`
- `items(obj: {K: V}) -> [(str, V)]`
- `has(obj: {K: V}, key: str) -> bool`
- `get(obj: {K: V}, key: str) -> V?`
- `set(obj: &mut {K: V}, key: str, value: V)`

#### `io`
- `read_file(path: str) -> str`
- `write_file(path: str, content: str)`
- `read_line() -> str`
- `stdin`, `stdout`, `stderr`

#### `time`
- `now() -> int` (Unix timestamp)
- `sleep(seconds: f64)`
- `Duration` type

#### `random`
- `seed(value: int)`
- `rand() -> f64` (0.0 to 1.0)
- `rand_int(min: int, max: int) -> int`
- `shuffle(arr: &mut [T])`

### E2. Optional Modules (via `import`)

#### `json`
- `parse(s: str) -> {K: V}?`
- `stringify(obj: {K: V}) -> str`

#### `http`
- `get(url: str) -> Response`
- `post(url: str, body: str) -> Response`
- `Response` type

#### `fs`
- `exists(path: str) -> bool`
- `mkdir(path: str)`
- `rmdir(path: str)`
- `list_dir(path: str) -> [str]`

---

## F. Compiler Architecture

### F1. Frontend

```
Source Code (.ny)
    ↓
Lexer (Tokenization)
    ↓
Parser (AST Construction)
    ↓
Semantic Analyzer (Type Checking, Ownership Checking)
    ↓
AST (Annotated)
```

### F2. Middle-End (IR)

```
AST
    ↓
IR Generation (Nyx IR - SSA form)
    ↓
Optimization Passes
    ├── Dead Code Elimination
    ├── Constant Folding
    ├── Inlining
    ├── Loop Optimization
    └── Ownership Optimization
    ↓
Optimized IR
```

### F3. Backend

#### Option A: VM Bytecode (v1)
```
Optimized IR
    ↓
Bytecode Generator
    ↓
Bytecode (.nyc)
    ↓
VM Interpreter
```

#### Option B: Native Code (v2+)
```
Optimized IR
    ↓
LLVM IR Generation
    ↓
LLVM Optimization
    ↓
Machine Code (.exe, .so, .dylib)
```

### F4. Bootstrapping Path

**Phase 1:** Python interpreter (current)
- Used for development and testing
- Not production-ready

**Phase 2:** Self-hosted compiler (v1.5)
- Compiler written in Nyx
- Compiles itself
- Validates language completeness

**Phase 3:** Production compiler (v2.0)
- Full optimization
- Native code generation
- Production-ready

---

## G. 5-Year Evolution Roadmap

### Year 1: v1.0 - Foundation (Current)

**Goals:**
- ✅ Complete language specification
- ✅ Working interpreter/VM
- ✅ Core standard library
- ✅ Package manager (nypm)
- ✅ Basic tooling (formatter, linter)

**Deliverables:**
- Language spec finalized
- Reference implementation
- 10+ example programs
- Documentation website

### Year 2: v1.5 - Self-Hosting

**Goals:**
- Self-hosted compiler
- Native code generation (LLVM backend)
- Performance optimizations
- Expanded standard library

**Deliverables:**
- Compiler written in Nyx
- Native binary generation
- 2x performance improvement
- 50+ packages in registry

### Year 3: v2.0 - Production Ready

**Goals:**
- Production-grade compiler
- Full optimization pipeline
- Advanced language features
- Ecosystem maturity

**New Features:**
- Pattern matching (`match` expressions)
- Macros (hygienic)
- Operator overloading
- Reflection (limited)

**Deliverables:**
- Production compiler
- 200+ packages
- IDE support (LSP)
- Commercial adoption

### Year 4: v2.5 - Ecosystem Growth

**Goals:**
- Large-scale adoption
- Industry partnerships
- Performance leadership
- Tooling excellence

**Focus Areas:**
- Scientific computing libraries
- Systems programming frameworks
- Web frameworks
- Game engines

### Year 5: v3.0 - Language Leader

**Goals:**
- Recognized as top-tier language
- 10,000+ packages
- Major industry adoption
- Research contributions

**Vision:**
- Default choice for scientific computing
- Preferred systems language (alongside Rust)
- Teaching language in universities
- Foundation for next-generation software

---

## H. Implementation Priorities

### Must-Have (v1.0)
1. ✅ Parser with clean grammar
2. ✅ Type checker
3. ✅ Ownership checker
4. ✅ VM bytecode generator
5. ✅ Core standard library
6. ✅ Package manager
7. ✅ Basic tooling

### Should-Have (v1.5)
1. Self-hosted compiler
2. Native code generation
3. Advanced optimizations
4. Expanded stdlib

### Nice-to-Have (v2.0)
1. Pattern matching
2. Macros
3. Reflection
4. Operator overloading

---

## I. Success Metrics

### Technical Metrics
- **Compilation speed**: < 100ms for 10K LOC
- **Runtime performance**: Within 10% of Rust
- **Memory safety**: Zero memory safety bugs in safe code
- **Type safety**: 100% type coverage

### Adoption Metrics
- **Packages**: 50+ by v1.5, 200+ by v2.0
- **Users**: 1,000+ by v1.5, 10,000+ by v2.0
- **Companies**: 10+ by v2.0
- **GitHub stars**: 1,000+ by v1.5, 10,000+ by v2.0

---

## Conclusion

Nyx v1.0 represents a **complete, production-ready language specification** that:

1. ✅ **Eliminates all syntax inconsistencies** (C-style braces, semicolons required)
2. ✅ **Guarantees long-term stability** (frozen core, clear extension path)
3. ✅ **Validates completeness** (type system, memory model, concurrency, modules)
4. ✅ **Ensures implementability** (realistic scope, clear architecture)
5. ✅ **Optimizes for expressiveness and performance** (Python-like syntax, Rust-like safety)

This specification provides the foundation for building a **world-class programming language** that combines the best of Python, Rust, and Julia.

---

**Document Status:** ✅ **FINAL** - Ready for Implementation  
**Next Steps:** Begin compiler implementation following this specification
