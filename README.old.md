# Nyx Programming Language

**A multi-paradigm, compiled programming language for high-performance computing, systems programming, AI/ML, and full-stack development.**

**Version:** 5.5.0  
**Author:** Surya Sekhar Roy  
**License:** Proprietary (see [LICENSE](LICENSE))  
**Copyright:** © 2026 Surya Sekhar Roy. All Rights Reserved.

---

## Table of Contents

1. [Overview](#overview)
2. [Installation & Quick Start](#installation--quick-start)
3. [Language Fundamentals](#language-fundamentals)
4. [Type System](#type-system)
5. [Ownership & Memory Safety](#ownership--memory-safety)
6. [Concurrency & Async](#concurrency--async)
7. [Standard Library](#standard-library)
8. [Engine Ecosystem (117 Engines)](#engine-ecosystem-117-engines)
9. [Compiler & Runtime Architecture](#compiler--runtime-architecture)
10. [Native C Implementation](#native-c-implementation)
11. [Native HTTP Server](#native-http-server)
12. [Tooling](#tooling)
13. [Examples](#examples)
14. [Benchmarks](#benchmarks)
15. [Configuration](#configuration)
16. [Testing](#testing)
17. [Documentation Index](#documentation-index)

---

## Overview

Nyx is an **expression-oriented, functional-first** language that also supports imperative and object-oriented programming. It combines the expressiveness of high-level languages like Python with the performance and control of Rust and C++.

### Core Design Principles

- **Functional-first:** First-class functions, closures, pipelines (`|>`), immutability by default
- **Object-Oriented:** Classes, traits (interfaces), generics, inheritance
- **Imperative:** Mutable state and traditional control flow when needed
- **Memory-safe:** Compile-time ownership and borrowing system (no garbage collector)
- **Strongly typed:** Static type system with smart type inference
- **Multi-target:** AOT compilation to native, JIT for interactive use, bytecode VM, WASM, JavaScript

### Key Differentiators

| Feature | Nyx | Python | Rust | C++ |
|---|---|---|---|---|
| Syntax verbosity | Ultra-low (50-70% fewer LOC) | Low | Medium | High |
| Memory safety | Ownership + borrowing | GC | Ownership + borrowing | Manual |
| Concurrency | async/await + channels + actors | GIL-limited | async/await + channels | Threads |
| Type inference | Full | Dynamic | Partial | Partial |
| Semicolons | Optional | None | Required | Required |
| Generics | Yes | Type hints | Yes | Templates |
| FFI | Native C/CUDA/OpenCL/BLAS | ctypes | extern | Native |
| File generation | 14+ formats natively | Libraries | Libraries | Libraries |
| Dual syntax | Python-style & C-style | One style | One style | One style |

### File Extensions

| Extension | Description |
|---|---|
| `.ny` | Primary Nyx source file |
| `.nx` | Legacy Nyx source file |

---

## Installation & Quick Start

### Prerequisites

- **Python 3.8+** (for the interpreter)
- **GCC/Clang** (for native compilation, optional)
- **Node.js** (for crypto CLI tools, optional)

### Running a Nyx Program

```bash
# Via Python interpreter
python run.py hello.ny

# Via native compiled binary
./build/nyx hello.ny

# Via shell scripts
./nyx.sh hello.ny        # Linux/macOS
nyx.bat hello.ny          # Windows
```

### Building the Native Compiler

```bash
# Using Make
make

# Using PowerShell build script (Windows)
powershell -File scripts/build_windows.ps1 -Output build/nyx.exe

# Manual GCC build
gcc -O2 -std=c99 -o build/nyx native/nyx.c -lm
```

Optional native features:
```bash
# With BLAS/LAPACK support
gcc -DNYX_BLAS -lopenblas -o nyx native/nyx.c

# With CUDA GPU support
nvcc -DNYX_CUDA -o nyx native/nyx.c -lcuda -lcublas -lcudart

# With OpenCL GPU support
gcc -DNYX_OPENCL -o nyx native/nyx.c -lOpenCL
```

### Hello World

```nyx
# hello.ny
print("Hello, World!")
```

### Package Manager (nypm)

```bash
nypm install <package-name>
```

Configuration in `nypm.config`:
```
registry=.\ny.registry
```

---

## Language Fundamentals

### Variables & Constants

```nyx
# Variable declaration
let x = 42
let name = "Nyx"
let pi = 3.14159

# With type annotation
let count: int = 0
let message: str = "hello"

# Short declaration
x := 42

# Constants
const MAX_SIZE = 1024
```

### Semicolons

**Semicolons are optional.** Both styles work:

```nyx
# Without semicolons (preferred)
let x = 5
let y = 10

# With semicolons
let x = 5;
let y = 10;

# Mixed (allowed)
let x = 5;
let y = 10

# Required for multiple statements on one line
let x = 1; let y = 2;

# Required in C-style for-loops
for (let i = 0; i < 10; i = i + 1) { ... }
```

### Dual Syntax (Python-Style & C-Style)

Nyx supports both indentation-based and brace-based blocks:

```nyx
# Python-style
if x > 0:
    print("positive")
else:
    print("non-positive")

# C-style
if (x > 0) {
    print("positive");
} else {
    print("non-positive");
}
```

### Functions

```nyx
# Standard function
fn add(a, b) {
    return a + b
}

# With type annotations
fn greet(name: str) -> str {
    return "Hello, " + name
}

# Minimal syntax (expression body)
add a b = a + b

# Lambda / closure
let double = fn(x) { return x * 2 }

# Async function
async fn fetch_data(url) {
    let response = await http.get(url)
    return response
}
```

### Control Flow

```nyx
# If/else
if condition {
    ...
} else if other {
    ...
} else {
    ...
}

# While loop
while x < 10 {
    x = x + 1
}

# For-in loop
for item in collection {
    print(item)
}

# Classic for loop
for (let i = 0; i < 10; i = i + 1) {
    print(i)
}

# Switch/case
switch value {
    case 1: print("one")
    case 2: print("two")
    default: print("other")
}

# Pattern matching
match value {
    | 1 => "one"
    | 2 => "two"
    | _ => "other"
}

# Break and continue
for i in range(100) {
    if i == 50 { break }
    if i % 2 == 0 { continue }
    print(i)
}
```

### Classes & OOP

```nyx
class Animal {
    fn init(self, name, sound) {
        self.name = name
        self.sound = sound
    }

    fn speak(self) {
        print(self.name + " says " + self.sound)
    }
}

class Dog : Animal {
    fn init(self, name) {
        super.init(name, "Woof!")
    }

    fn fetch(self, item) {
        print(self.name + " fetches " + item)
    }
}

let dog = Dog("Rex")
dog.speak()       # "Rex says Woof!"
dog.fetch("ball") # "Rex fetches ball"
```

### Modules & Imports

Both `import` and `use` keywords work identically. Both quoted and unquoted forms are supported:

```nyx
# Unquoted (preferred)
import math
use http

# Quoted (legacy)
import "math"
use "http"

# From-import with selective symbols
from collections import LinkedList, HashMap

# Wildcard import
from math import *

# Module access
let result = math::sqrt(16)
# Or dot notation
let result = math.sqrt(16)
```

### Error Handling

```nyx
try {
    let result = risky_operation()
} catch (err) {
    print("Error: " + str(err))
}

# Throw/raise
throw "Something went wrong"
raise "Custom error"

# Assert
assert x > 0, "x must be positive"

# With statement (RAII)
with open("file.txt") as f {
    let content = f.read()
}
```

### Operators

| Category | Operators |
|---|---|
| Arithmetic | `+` `-` `*` `/` `%` `**` `//` |
| Comparison | `==` `!=` `<` `>` `<=` `>=` `<=>` (spaceship) |
| Logical | `&&` `\|\|` `!` |
| Bitwise | `&` `\|` `^` `~` `<<` `>>` |
| Assignment | `=` `+=` `-=` `*=` `/=` `%=` `//=` `:=` `??=` |
| Null-safety | `?.` (optional chaining) `??` (null coalesce) |
| Pipeline | `\|>` |
| Range | `..` |
| Type | `::` (namespace/path separator) |

### Literals

| Type | Examples |
|---|---|
| Integer | `42`, `1_000_000` |
| Float | `3.14`, `1.0e-10` |
| Binary | `0b1010` |
| Octal | `0o755` |
| Hex | `0xFF` |
| String | `"hello"`, `'world'` |
| Format string | `f"Hello {name}"` |
| Raw string | `r"no\escape"` |
| Byte string | `b"bytes"` |
| Boolean | `true`, `false` |
| Null | `null` |
| Array | `[1, 2, 3]` |
| Object/Map | `{"key": "value"}` |

### Generators & Yield

```nyx
fn fibonacci() {
    let a = 0
    let b = 1
    while true {
        yield a
        let temp = a + b
        a = b
        b = temp
    }
}
```

### Comprehensions

```nyx
let squares = [x * x for x in range(10)]
let evens = [x for x in range(20) if x % 2 == 0]
```

---

## Type System

### Primitive Types

| Type | Description | Size |
|---|---|---|
| `int` | Default integer | Platform-dependent |
| `i8`, `i16`, `i32`, `i64` | Signed integers | 1-8 bytes |
| `u8`, `u16`, `u32`, `u64` | Unsigned integers | 1-8 bytes |
| `f32` | 32-bit float | 4 bytes |
| `f64` | 64-bit float | 8 bytes |
| `bool` | Boolean | 1 byte |
| `char` | Unicode character | 4 bytes |
| `str` | UTF-8 string | Dynamic |
| `null` | Null value | 0 bytes |
| `void` | No value | 0 bytes |
| `never` | Never returns | 0 bytes |

### Compound Types

```nyx
# Arrays
let arr: [int] = [1, 2, 3]

# Slices
let s: [int] = arr[1..3]

# Tuples
let point: (int, int) = (10, 20)

# Objects / Maps
let obj: {str: int} = {"a": 1, "b": 2}

# Functions
let f: fn(int, int) -> int = add
```

### User-Defined Types

```nyx
# Classes
class Point {
    x: f64
    y: f64
}

# Structs
struct Color {
    r: u8
    g: u8
    b: u8
    a: u8
}

# Enums
enum Direction {
    North,
    South,
    East,
    West
}

# Algebraic / tagged enums
enum Option<T> {
    Some(T),
    None
}

enum Result<T, E> {
    Ok(T),
    Err(E)
}

# Type aliases
type StringList = [str]
```

### Generics

```nyx
fn identity<T>(value: T) -> T {
    return value
}

class Stack<T> {
    items: [T]

    fn push(self, item: T) { ... }
    fn pop(self) -> T { ... }
}
```

### References & Borrowing

```nyx
# Immutable reference
let r: &int = &x

# Mutable reference
let r: &mut int = &mut x
```

### Advanced Type Features

- **Dependent types** — types that depend on values
- **Refinement types** — types with logical predicates
- **GADTs** — Generalized Algebraic Data Types
- **Higher-Kinded Types (HKT)** — types parameterized by type constructors
- **Linear types** — values that must be used exactly once
- **Comptime** — compile-time evaluation

---

## Ownership & Memory Safety

Nyx uses a **Rust-inspired ownership system** to guarantee memory safety at compile time without a garbage collector.

### Ownership Rules

1. Every value has exactly **one owner**
2. When the owner goes out of scope, the value is **dropped**
3. Values can be **moved** (ownership transfer) or **borrowed** (temporary access)

```nyx
let s1 = String::new("hello")
let s2 = s1  # s1 is MOVED to s2 — s1 is no longer valid

# Borrowing
fn print_len(s: &str) {  # immutable borrow
    print(len(s))
}

fn append(s: &mut str) {  # mutable borrow
    s.push("!")
}
```

### Borrow Rules

- You can have **many immutable borrows** (`&T`) OR **one mutable borrow** (`&mut T`), never both simultaneously
- References must always be **valid** (no dangling pointers)
- The borrow checker prevents use-after-move

### Lifetimes

```nyx
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if len(x) > len(y) { return x }
    return y
}
```

### RAII (Resource Acquisition Is Initialization)

```nyx
# Resources are automatically cleaned up when they go out of scope
{
    let file = open("data.txt")
    # ... use file ...
}  # file is automatically closed here (drop() called)
```

### Smart Pointers

| Type | Description | Thread-Safe |
|---|---|---|
| `Box<T>` | Unique ownership (heap-allocated) | No |
| `Rc<T>` | Reference-counted (single-threaded) | No |
| `Arc<T>` | Atomic reference-counted | Yes |
| `Weak<T>` | Non-owning reference (no prevent drop) | Depends |

```nyx
let boxed = Box::new(42)
let shared = Rc::new("hello")
let atomic_shared = Arc::new(data)
let weak_ref = Rc::downgrade(shared)
```

### Send & Sync Traits

- **Send**: Type can be transferred between threads
- **Sync**: Type can be shared between threads via references

---

## Concurrency & Async

### Async/Await

```nyx
async fn fetch_user(id: int) -> User {
    let response = await http.get(f"/api/users/{id}")
    return json.parse(response.body)
}

# Spawn concurrent tasks
let task1 = spawn fetch_user(1)
let task2 = spawn fetch_user(2)
let results = await all([task1, task2])
```

### Event Loop

```nyx
import async

let loop = async.EventLoop()
loop.add_task(async_function)
loop.run_until_complete()
```

### Futures & Promises

```nyx
let future = Future::new()
future.then(fn(value) { print("Got: " + str(value)) })
      .catch(fn(err) { print("Error: " + str(err)) })

future.resolve(42)  # Triggers .then callback
```

### Channels

```nyx
# Unbuffered channel
let (tx, rx) = channel()

# Buffered channel
let (tx, rx) = channel(buffer_size: 100)

# Send and receive
tx.send("hello")
let msg = rx.recv()
```

### Synchronization Primitives

| Primitive | Description |
|---|---|
| `Mutex` | Mutual exclusion lock |
| `RwLock` | Reader-writer lock |
| `Semaphore` | Counting semaphore |
| `Barrier` | Synchronization barrier |
| `CondVar` | Condition variable |
| `Once` | One-time initialization |
| `Atomics` | Lock-free atomic operations |

### Select Statement

```nyx
select {
    case msg = <-channel1: handle_msg(msg)
    case err = <-channel2: handle_err(err)
    case <-timeout(5000): print("timed out")
}
```

---

## Standard Library

The standard library provides **60+ modules** covering every domain.

### Core Modules

| Module | Description | Key Exports |
|---|---|---|
| `math` | Mathematics | `PI`, `E`, `TAU`, `PHI`, `sqrt`, `abs`, `sin`, `cos`, `clamp`, `floor`, `ceil`, `round`, `hypot`, `cbrt` + 30 constants |
| `string` | String manipulation | `upper`, `lower`, `capitalize`, `title`, `strip`, `split`, `replace`, `contains`, `starts_with`, `ends_with` |
| `io` | File I/O | `read_file`, `write_file`, `append_file`, `file_exists`, `mkdir`, `list_dir`, `copy_file`, `delete_file`, `join_path` |
| `json` | JSON parsing/generation | `parse`, `stringify`, `pretty` (recursive descent parser) |
| `time` | Time & date | `now`, `now_millis`, `sleep`, `parse_iso`, `format_time`, `to_components` |
| `types` | Type inspection | `type_of`, `is_int`, `is_bool`, `is_string`, `is_array`, `is_function`, `is_null` |
| `algorithm` | Algorithms | `sort` (quicksort), `binary_search`, `find`, `filter`, `map`, `reduce`, `unique`, `reverse` |
| `collections` | Data structures | `LinkedList`, `Stack`, `Queue`, `HashMap`, `TreeMap`, `Set` |
| `test` | Testing framework | `assert`, `eq`, `neq`, `raises`, `approx`, `contains_`, `skip`, `suite`, `summary` |
| `log` | Logging | `Logger`, `ConsoleHandler`, `FileHandler` with levels: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` |

### Networking & Web

| Module | Description | Key Exports |
|---|---|---|
| `http` | HTTP client | `request`, `get`, `parse_url`, `parse_http_response` |
| `web` | Web framework | `Router` (get/post/put/delete/patch), `Request`, `Response`, middleware, route groups |
| `socket` | Raw sockets | `TCPSocket`, `TCPServer`, `UDPSocket`, `connect`, `send`, `recv` |
| `network` | Network utilities | IP address parsing, DNS types, HTTP status codes, protocol constants |
| `redis` | Redis client | `RedisClient` with full command support, pub/sub, transactions, Lua scripting |
| `jwt` | JSON Web Tokens | `JWTHeader`, `JWTPayload`, token creation/validation, HS256-PS512 algorithms, OAuth flows |

### Security & Crypto

| Module | Description | Key Exports |
|---|---|---|
| `crypto` | Hash functions | `fnv1a32/64`, `djb2`, `crc32` (fast lookup), `crc16`, `crc64`, `murmur3_32/128` |
| `validator` | Data validation | `Validator`, `SchemaValidator`, `ValidationResult`, error codes, format validators |

### Data & Serialization

| Module | Description | Key Exports |
|---|---|---|
| `database` | Embedded database | `KVStore`, `FileKVStore`, `Table` (SQL-like with schema), `Index` |
| `config` | Config parsing | TOML, YAML, INI parsers with `Config` struct |
| `serialization` | Binary encoding | `BinarySerializer`/`BinaryDeserializer`, MessagePack, Protocol Buffers |
| `xml` | XML processing | `XMLParser`, `XMLElement`, `XMLDocument`, XPath, DOM manipulation |
| `regex` | Regular expressions | `compile`, `match`, `find_all`, `replace_all`, character classes |
| `compress` | Compression | `gzip_compress`, `gzip_decompress`, `zip_create` |

### AI/ML & Scientific

| Module | Description | Key Exports |
|---|---|---|
| `tensor` | Tensor operations | `Tensor`, `zeros`, `ones`, `full`, `eye`, autograd support |
| `nn` | Neural networks | `Module`, `Linear`, `Conv1d`, `Conv2d`, `Parameter`, train/eval modes |
| `science` | Linear algebra | `Vector` (dot, cross, normalize, project), `Matrix` (multiply, transpose, determinant) |
| `distributed` | Distributed training | `ProcessGroup`, `all_reduce`, `all_gather`, `broadcast`, `DataParallel`, `ParameterServer` |

### Systems & Low-Level

| Module | Description | Key Exports |
|---|---|---|
| `ffi` | Foreign Function Interface | `Library`, `CFunction`, C type constants, `malloc`/`free`, `call`, pointer ops |
| `simd` | SIMD intrinsics | `Vec2f`, `Vec4f`, `Vec8f`, SSE/AVX/AVX-512/NEON/SVE detection |
| `process` | Process management | `Process` (pid, cpu_percent, terminate, kill), `Popen` (stdin/stdout/stderr) |
| `ownership` | Advanced ownership | `Lifetime`, `LifetimeInference`, `OwnershipTracker`, constraint solving (1,200 lines) |
| `smart_ptrs` | Smart pointers | `Box<T>`, `Rc<T>`, `Arc<T>`, `Weak<T>`, cycle detection, leak detection |
| `realtime` | Real-time systems | `CPUAffinity`, `ThreadPriority`, `SchedulingPolicy` (FIFO/RR/deadline), `RealTimeTask` |
| `vm` | Virtual Machine | `VirtualMachine`, `GuestMemory`, `VCPUState`, UEFI/BIOS boot, PCI, ACPI, hypercalls, snapshot/migration |

### Development Tools

| Module | Description | Key Exports |
|---|---|---|
| `cli` | CLI argument parsing | `Parser`, `Arg`, `ArgType`, commands, `parse_args`, `print_help` |
| `lsp` | Language Server Protocol | `LanguageServer`, `Position`, `Range`, `CompletionItem`, `Diagnostic`, `Hover` |
| `parser` | Parser combinators | `InputStream`, `ParseResult`, `ParseError`, combinator functions |
| `state_machine` | State machines | `StateMachine`, `State`, `Event`, FSM/HSM/StateChart, transition history |
| `metrics` | Prometheus metrics | `Counter`, `Gauge`, `Histogram`, `Summary`, `Labels`, Prometheus export |
| `generator` | File generation | 14+ formats: TXT, MD, CSV, RTF, SVG, BMP, PNG, ICO, PDF, DOCX, XLSX, PPTX, ODT, ODS — all 100% native |
| `game` | Game framework | `Game`, color/key/mouse/joystick constants, scene management |
| `gui` | GUI toolkit | `Application`, `Window`, widgets, menus, toolbars, timers, event binding |

---

## Engine Ecosystem (117 Engines)

Nyx ships with **117 specialized, production-ready engines** organized into 9 categories. Every engine includes health monitoring, metrics, structured logging, error handling, circuit breakers, graceful shutdown, and distributed tracing.

### Engine Categories

| Category | Count | Examples |
|---|---|---|
| **Core Infrastructure** | ~15 | `nycore`, `nyruntime`, `nyasync`, `nycache`, `nysync`, `nysys`, `nysystem` |
| **AI/ML** | 21 | `nyai`, `nygrad`, `nyml`, `nymodel`, `nyrl`, `nyagent`, `nyloss`, `nymind` |
| **Data Processing** | 18 | `nydata`, `nydatabase`, `nyquery`, `nycompute`, `nystorage`, `nystream` |
| **Security** | 17 | `nycrypto`, `nysec`, `nysecure`, `nyaudit`, `nyexploit`, `nyrecon`, `nymal` |
| **Web & APIs** | 15 | `nyhttp`, `nyapi`, `nyserver`, `nyweb`, `nyserve`, `nygui` |
| **DevOps & Cloud** | ~15 | `nykube`, `nydeploy`, `nyci`, `nycloud`, `nycontainer`, `nyprovision`, `nyinfra` |
| **Scientific** | ~10 | `nysci`, `nybio`, `nychem`, `nyquant`, `nyhft`, `nystats` |
| **Graphics & Media** | ~10 | `nyrender`, `nyanim`, `nyaudio`, `nygame`, `nyviz`, `nymedia`, `nygpu` |
| **Utilities** | ~16 | `nypack`, `nypm`, `nydoc`, `nyshell`, `nyscript`, `nybuild`, `nyreport` |

### Usage Pattern

```nyx
use nyai
use production

let runtime = production.ProductionRuntime::new()

# Use any engine with production features built-in
let model = nyai.Model::new("classifier")
model.train(data)
let prediction = model.predict(input)

# Health monitoring
let health = runtime.check_health()
println(health.status)  # "healthy"

# Metrics
runtime.metrics.increment("predictions_total", 1)
```

### AAA Game Engine Profile

The engine ecosystem includes AAA game development capabilities defined in `configs/production/aaa_engine_feature_contract.json`:

**nycore:** allocators, work-stealing, NUMA-aware, task graph, ECS, fiber runtime, SIMD dispatch, self-optimizing runtime

**nyrender:** spectral PBR, ray tracing (hardware RT cores, hybrid RT, path tracing), neural radiance GI, virtual geometry, mesh shaders, Vulkan/DX12/Metal/WebGPU backends, HDR pipeline, denoising, AI shader optimization

**nyphysics:** rigid body, soft body, cloth, fluid, destruction, ragdoll, vehicle physics

**nyaudio:** spatial audio, HRTF, convolution reverb, Wwise/FMOD integration

**nyanim:** skeletal animation, IK, blend trees, motion matching, facial animation, procedural animation

---

## Compiler & Runtime Architecture

### Execution Pipeline

```
Source (.ny) → Lexer → Parser → AST → Interpreter/Compiler → Output
```

### Python Interpreter (Primary)

The primary interpreter is implemented in Python across these modules:

| File | Purpose | Key Classes |
|---|---|---|
| `run.py` | Entry point | Reads `.ny` file → Lexer → Parser → evaluate |
| `src/lexer.py` | Tokenization | `Lexer` with `Options` (hash comments, block comments, multiline strings, format strings, raw strings, byte strings, unicode identifiers), `LexerState` save/restore |
| `src/token_types.py` | Token definitions | `TokenType` enum (100+ tokens), `Token` dataclass, `TokenRegistry` |
| `src/parser.py` | Parsing | `Parser` with Pratt parsing (prefix/infix), `Precedence` enum, extensible via `register_prefix/infix/statement` hooks |
| `src/ast_nodes.py` | AST definitions | `Node` base with `SourceLocation`, `NodeVisitor` pattern, 30+ node types (`LetStatement`, `IfExpression`, `FunctionLiteral`, `ClassStatement`, `ForInStatement`, `TryStatement`, `AsyncStatement`, etc.) |
| `src/interpreter.py` | Evaluation | `Interpreter` (tree-walking), `Environment` (scope chain), `NyxClass`, `UserFunction`, type wrappers (`Integer`, `Float`, `Boolean`, `String`, `Null`, `Array`, `Error`), 1M step limit |
| `src/borrow_checker.py` | Ownership checking | `BorrowChecker`, `SafeSubsetDefinition` (6 rules), `PerformanceModel` (zero-cost abstraction verification) |
| `src/ownership.py` | Ownership system | `OwnershipContext`, `Lifetime`, `Borrow`, `RAIIManager`, `RAIIScope`, `ThreadSafety` (Send/Sync), `Owner` lifecycle |
| `src/compiler.py` | Multi-target compiler | `Target` (JS/WASM/Native/Bytecode), `CompileOptions`, AST → target code generation |
| `src/debugger.py` | Error detection | `ErrorDetector` with rules: balanced parens/braces/brackets, unterminated strings, assignment-in-condition, null comparison |
| `src/polyglot.py` | Multi-language runner | `PolyglotRunner` with `Language` enum (25 languages), auto-detection, block splitting |
| `src/async_runtime.py` | Async engine | `NyxEventLoop` (singleton), `Promise` (then/catch/wait), `AsyncTask` with priority queue, `ThreadPoolExecutor` |
| `src/stability.py` | Compatibility config | `NyxStabilityConfig` (noop directives, modifier keywords, runtime rewrites like `::` → `.`), engine module discovery |

### Built-in Functions

The interpreter provides these built-in functions:

| Function | Description |
|---|---|
| `print(...)` | Output values to stdout |
| `len(x)` | Length of string, array, or collection |
| `range(n)` | Generate `[0, 1, ..., n-1]` |
| `max(a, b)` | Maximum of two values |
| `min(a, b)` | Minimum of two values |
| `sum(arr)` | Sum of array elements |
| `abs(x)` | Absolute value |
| `round(x)` | Round to nearest integer |
| `str(x)` | Convert to string |
| `int(x)` | Convert to integer |
| `float(x)` | Convert to float |
| `type(x)` | Get type name as string |
| `push(arr, x)` | Append to array |
| `pop(arr)` | Remove last element |
| `keys(obj)` | Get object keys |
| `values(obj)` | Get object values |
| `has_key(obj, k)` | Check if key exists |
| `contains(s, sub)` | Check substring |
| `replace(s, old, new)` | String replace |
| `split(s, delim)` | Split string |
| `join(arr, delim)` | Join array to string |
| `trim(s)` | Strip whitespace |
| `sort(arr)` | Sort array |
| `slice(arr, s, e)` | Array slice |
| `map(arr, fn)` | Map function over array |
| `filter(arr, fn)` | Filter array |

### Bootstrap Compiler

The `src/bootstrap.ts` TypeScript file generates a self-hosting C runtime by embedding the complete VM architecture (Lexer, Parser, AST, Bytecode VM) as a C string constant, which gets compiled to a standalone native compiler.

---

## Native C Implementation

The file `native/nyx.c` is a complete, standalone C implementation of the Nyx runtime featuring:

### Memory Safety Layer

```c
NYX_SAFE_MALLOC(ptr, size, on_fail)   // Tracked allocation with null check
NYX_NULL_CHECK(ptr, msg)               // Runtime null pointer check
NYX_BOUNDS_CHECK(idx, size, msg)       // Array bounds checking
NYX_OVERFLOW_CHECK(a, b, op, msg)      // Integer overflow detection
NYX_SAFE_FREE(ptr)                     // Tracked deallocation (sets to NULL)
NYX_DEFENSIVE_COPY(dest, src, size)    // Safe copy
```

Safety can be toggled at compile time:
- `NYX_SAFETY_ENABLED` — master switch (default: on)
- `NYX_TRACKING_ENABLED` — allocation tracking (enabled in DEBUG builds)

### Native Token Types

The C lexer supports: `let`, `if`, `else`, `switch`, `case`, `default`, `while`, `for`, `in`, `break`, `continue`, `class`, `module`, `typealias`, `try`, `catch`, `throw`, `fn`, `return`, `import`, `use`, `true`, `false`, `null`

### Memory Management

- `xmalloc`/`xrealloc`/`xfree` with allocation tracking via `AllocTracker`
- `atexit` cleanup hook prevents memory leaks
- `xstrdup`/`xstrndup` for safe string handling

---

## Native HTTP Server

Nyx includes a production-grade, Apache-style HTTP/1.1 server implemented in C:

### Features

- Multi-threaded worker pool (configurable thread count)
- Event-driven I/O (epoll/kqueue/IOCP)
- Virtual hosts and URL routing
- Static file serving with caching
- SSL/TLS 1.3 support
- Request/response middleware
- Access logging (Common/Combined format)
- Configurable timeouts and limits
- Graceful restart/shutdown

### C API (`native/nyx_httpd.h`)

```c
NyxHttpServer* nyx_httpd_create(const NyxHttpdConfig *config);
int nyx_httpd_route(NyxHttpServer *server, const char *method, const char *path, NyxHttpHandler handler, void *user_data);
int nyx_httpd_middleware(NyxHttpServer *server, NyxHttpHandler middleware, void *user_data);
int nyx_httpd_start(NyxHttpServer *server);         // Blocking
int nyx_httpd_start_async(NyxHttpServer *server);    // Background
int nyx_httpd_stop(NyxHttpServer *server);
void nyx_httpd_destroy(NyxHttpServer *server);
```

### Nyx Wrapper (`native/nyhttpd.ny`)

```nyx
import nyhttpd

let server = HttpServer::new({
    "port": 8080,
    "worker_threads": 4
})

server.get("/", fn(req, res) {
    res.json({"message": "Hello, World!"})
})

server.post("/api/data", fn(req, res) {
    let body = req.body
    res.status(201).json({"created": true})
})

server.listen()
```

---

## Tooling

### VS Code Extension

A full-featured VS Code extension is available at `editor/vscode/nyx-language/`:

- Syntax highlighting for `.ny` and `.nx` files
- Bracket matching and auto-closing
- Code snippets for common patterns
- Language configuration

### Nyx Studio

An integrated development environment (`tools/nyx_studio/`) with:

- **Local web server** (`studio_server.py`) on port 4173
- **Material graph compiler** — visual node-based material editing
- **Render pipeline designer** — visual render pipeline configuration
- **World rule editor** — declarative game world logic
- **Logic rule compiler** — event-based game behavior
- **Project save/load** with SHA-256 content hashing

### Crypto CLI (`cli.js`)

Node.js command-line tools:
```bash
node cli.js encrypt <text> <password>    # AES-256-GCM encryption
node cli.js decrypt <encrypted> <password>
node cli.js hash <text> [algorithm]       # SHA-256, SHA-512, MD5
node cli.js sign <text> <key>             # HMAC signing
node cli.js verify <text> <sig> <key>
node cli.js uuid                          # Generate UUID v4
```

### HTTP Tools (`index.js`)

Node.js HTTP utilities:
```bash
node index.js                             # Start HTTP server
```

### Python Runtime Server (`nyx_runtime.py`)

Production-grade HTTP server for running Nyx programs:

```bash
python nyx_runtime.py script.ny --host 0.0.0.0 --port 8080
```

**Endpoints:**
- `GET /api/health` — Health check with metrics
- `GET /api/overview` — Runtime overview
- `GET /api/metrics` — Performance metrics
- `POST /api/community/subscribe` — Email signup
- `POST /api/playground/run` — Execute Nyx code

Features: `PersistentStore` (thread-safe JSON with atomic writes), `Application` (route handling, worker pool), `RuntimeConfig`, request metrics tracking.

---

## Examples

### Hello World
```nyx
print("Hello, World!")
```

### Fibonacci
```nyx
fn fib(n) {
    if n <= 1 { return n }
    return fib(n - 1) + fib(n - 2)
}
print(fib(10))  # 55
```

### Web Server
```nyx
import web

let app = web.Router()

app.get("/", fn(req) {
    return web.Response().json({"message": "Welcome to Nyx!"})
})

app.post("/api/users", fn(req) {
    let user = json.parse(req.body)
    return web.Response().status(201).json(user)
})
```

### Machine Learning
```nyx
import tensor
import nn

class NeuralNetwork : nn.Module {
    fn init(self) {
        self.layer1 = nn.Linear(784, 128)
        self.layer2 = nn.Linear(128, 10)
    }

    fn forward(self, x) {
        x = self.layer1.forward(x)
        x = nn.relu(x)
        x = self.layer2.forward(x)
        return x
    }
}
```

### OS Kernel (x86_64)
```nyx
# Bare-metal x86_64 kernel with GRUB Multiboot2
import systems

@section(".multiboot2")
const MULTIBOOT2_HEADER = [0xE85250D6, 0, 24, -(0xE85250D6 + 24)]

@entry
fn _start() {
    let vga = 0xB8000 as *mut u16
    unsafe { *vga = 0x0F4E }  # 'N' in white
    loop { halt() }
}
```

### Embedded Firmware (ARM Cortex-M4F)
```nyx
import systems

@section(".vector_table")
const VECTOR_TABLE = [0x20010000, _start, /* handlers... */]

@entry
fn _start() {
    systems.mmio_write(0x40021000, 0x00000004)  # Enable GPIOA clock
    # ... bare-metal MMIO operations ...
}
```

### Calculator with GUI
```nyx
import gui

let app = gui.Application()
let window = gui.Window("Calculator", 300, 400)

# Build calculator UI with buttons and display
window.mainloop()
```

### Game Development
```nyx
import game

let g = game.Game("My Game", 800, 600)
g.init_game()
g.set_scene("main_menu")
```

More examples in the `examples/` directory:
- `calculator.ny` — Advanced math with Matrix and Complex number classes
- `comprehensive.ny` — Full language feature showcase
- `http_server_native.ny` — Complete HTTP server with routes
- `ml_training.ny` — Neural network training pipeline
- `fullstack_app/school_admission.ny` — Full-stack school management application

---

## Benchmarks

Benchmark programs in `benchmarks/`:

| Benchmark | Description | Workload |
|---|---|---|
| `bench_fib.ny` | Recursive Fibonacci | `fib(20)` |
| `bench_loops.ny` | Nested loops | 100×100 iterations |
| `bench_array.ny` | Array operations | 1,000 elements |
| `bench_string.ny` | String concatenation | 1,000 concatenations |
| `bench_functions.ny` | Function call overhead | 1,000 calls |
| `bench_hash.ny` | Dictionary operations | 500 insert/lookup/delete |

### Nyx vs Python Benchmark Suite

`benchmarks/nyx_vs_python_benchmark.py` provides automated comparison:
```bash
python benchmarks/nyx_vs_python_benchmark.py
```

---

## Configuration

### Production Configs (`configs/production/`)

| File | Purpose |
|---|---|
| `aaa_engine_feature_contract.json` | AAA game engine feature requirements per engine |
| `anti_cheat_rules.json` | Anti-cheat configuration |
| `content_targets.json` | Content delivery targets |
| `cook_profile.json` | Asset cooking profiles |
| `gate_thresholds.json` | Quality gate thresholds |
| `gta_scale_program.json` | Scale testing configuration |
| `hardware_matrix.json` | Hardware compatibility matrix |
| `liveops_slo.yaml` | Live operations SLO definitions |
| `multi_year_plan.json` | Development roadmap |
| `platform_cert_matrix.json` | Platform certification requirements |
| `team_roster.json` | Team configuration |

### Stability Configuration (`.nyx/stability.json`)

```json
{
    "parser": {
        "noop_directives": ["use", "import"],
        "modifier_keywords": ["pub"]
    },
    "runtime": {
        "auto_call_main": true,
        "rewrites": [
            {"pattern": "::", "replacement": "."},
            {"pattern": "\\.starts_with\\(", "replacement": ".startswith("}
        ]
    },
    "modules": {
        "extra": ["custom_module"]
    }
}
```

---

## Testing

### Test Structure

Tests are organized by level in `tests/`:

| Directory | Focus |
|---|---|
| `level1_lexer/` | Tokenization tests |
| `level2_parser/` | Parse tree tests |
| `level3_interpreter/` | Evaluation tests |
| `level4_stress/` | Stress & load tests |
| `level5_stdlib/` | Standard library tests |
| `level6_security/` | Security tests |
| `level7_performance/` | Performance benchmarks |
| `level8_compliance/` | Compliance checks |
| `level9_consistency/` | Cross-platform consistency |
| `level10_realworld/` | Real-world scenarios |

### Running Tests

```bash
# All Python tests
python tests/run_all_tests.py

# Individual test files
python -m pytest tests/test_lexer.py
python -m pytest tests/test_parser.py
python -m pytest tests/test_interpreter.py
python -m pytest tests/test_borrow_checker.py
python -m pytest tests/test_ownership.py
python -m pytest tests/test_polyglot.py

# Nyx test files
python run.py tests/test_basic.ny
python run.py tests/test_stdlib.ny
python run.py tests/test_semicolons.ny
python run.py tests/test_use.ny

# JavaScript tests
node tests/test-all.js
```

---

## Documentation Index

Full documentation in `docs/`:

| Document | Description |
|---|---|
| [LANGUAGE_SPEC.md](docs/LANGUAGE_SPEC.md) | Complete language specification |
| [NYX_LANGUAGE_SPEC.md](docs/NYX_LANGUAGE_SPEC.md) | Core philosophy & syntax |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System architecture |
| [FEATURE_MAP.md](docs/FEATURE_MAP.md) | Feature inventory (ownership, dependent types, GADTs, HKT, comptime) |
| [DUAL_IMPORT_SYNTAX.md](docs/DUAL_IMPORT_SYNTAX.md) | Import/use dual syntax guide |
| [ECOSYSTEM.md](docs/ECOSYSTEM.md) | 30+ stdlib modules, security model |
| [concurrency_model.md](docs/concurrency_model.md) | Worker pools, semaphores, atomic persistence |
| [memory_model.md](docs/memory_model.md) | Bounded queues, copy-on-read, render memory |
| [observability.md](docs/observability.md) | Metrics endpoints, trace hooks, health |
| [distributed_mode.md](docs/distributed_mode.md) | StateProvider, rate limiting, replay |
| [legacy_syntax.md](docs/legacy_syntax.md) | Python-style vs brace-style reference |
| [NATIVE_IMPLEMENTATION.md](docs/NATIVE_IMPLEMENTATION.md) | 100% native file generation |
| [BENCHMARKS.md](docs/BENCHMARKS.md) | Performance comparisons |
| [CONTRIBUTING.md](docs/CONTRIBUTING.md) | Contribution guidelines |
| [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) | Deployment instructions |
| [BOOTSTRAP.md](docs/BOOTSTRAP.md) | Self-hosting compiler bootstrap |

### Formal Grammar

The complete EBNF grammar is at `language/grammar.ebnf`, covering:
- Program structure (statements, declarations)
- Expressions (assignment, logical, bitwise, equality, relational, arithmetic, power, unary, postfix, primary)
- Literals (numbers, strings, booleans, arrays, objects, functions)
- Control flow (if/else, while, for, switch, match)
- Class definitions (fields, methods, inheritance)
- Module system (import, use, from)
- Error handling (try/catch, throw, assert)
- Async (async/await, spawn)

---

## Project Structure

```
Nyx/
├── run.py                  # Main entry point (Python interpreter)
├── nyx_runtime.py          # Production HTTP runtime server
├── Makefile                # Native build system
├── package.json            # Package metadata (v5.5.0)
├── ny.registry             # Package registry
├── nypm.config             # Package manager config
├── nypm.js                 # Package manager
├── cli.js                  # Crypto CLI tools
├── index.js                # HTTP utilities
├── src/                    # Python interpreter source
│   ├── lexer.py            # Tokenizer
│   ├── token_types.py      # Token definitions (100+ types)
│   ├── parser.py           # Pratt parser
│   ├── ast_nodes.py        # AST node definitions
│   ├── interpreter.py      # Tree-walking evaluator
│   ├── compiler.py         # Multi-target compiler (JS/WASM/Native)
│   ├── borrow_checker.py   # Ownership/borrow verification
│   ├── ownership.py        # Ownership system implementation
│   ├── async_runtime.py    # Event loop & promises
│   ├── debugger.py         # Error detection & diagnostics
│   ├── polyglot.py         # Multi-language code runner
│   ├── stability.py        # Compatibility configuration
│   └── bootstrap.ts        # Self-hosting C runtime generator
├── native/                 # Native C implementation
│   ├── nyx.c               # Complete C runtime
│   ├── nyx_httpd.c          # Apache-style HTTP server
│   ├── nyx_httpd.h          # HTTP server API
│   └── nyhttpd.ny           # Nyx wrapper for native HTTP
├── compiler/               # Bootstrap compiler
│   ├── bootstrap.ny        # Nyx → C compiler (v2)
│   ├── v3_seed.ny          # v3 compiler seed
│   └── v3_compiler_template.c  # C compiler template
├── language/               # Language specification
│   ├── grammar.ebnf        # Formal grammar
│   ├── types.md            # Type system
│   ├── ownership.md        # Ownership model
│   ├── concurrency.md      # Concurrency model
│   └── MINIMAL_SYNTAX.md   # Ultra-concise syntax
├── stdlib/                 # Standard library (60+ modules)
├── engines/                # Engine ecosystem (117 engines)
├── examples/               # Example programs
├── tests/                  # Test suite (10 levels)
├── benchmarks/             # Performance benchmarks
├── docs/                   # Documentation
├── tools/nyx_studio/       # IDE / Studio tooling
├── editor/vscode/          # VS Code extension
├── configs/production/     # Production configurations
├── scripts/                # Build scripts
└── build/                  # Build output
```

---

*Nyx — One language for everything.*
