<p align="center">
  <img src="editor/vscode/nyx-language/assets/nyx-logo.png" alt="Nyx Logo" width="120" />
</p>

<h1 align="center">Nyx Programming Language</h1>

<p align="center">
  <strong>A memory-safe systems language that feels like Python, performs like Rust, and computes like Julia.</strong>
</p>

<p align="center">
  <code>v3.3.3</code> &nbsp;|&nbsp; Self-Hosting Compiler &nbsp;|&nbsp; Stack-Based VM &nbsp;|&nbsp; 60+ Stdlib Modules &nbsp;|&nbsp; 26 Engine Packages
</p>

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Quick Start](#quick-start)
- [Language at a Glance](#language-at-a-glance)
- [Architecture](#architecture)
- [Type System](#type-system)
- [Memory Model](#memory-model)
- [Concurrency](#concurrency)
- [Standard Library](#standard-library)
- [Engine Ecosystem](#engine-ecosystem)
- [Package Manager (nypm)](#package-manager-nypm)
- [Compiler Bootstrapping](#compiler-bootstrapping)
- [Version History](#version-history)
- [Build System](#build-system)
- [Runtime CLI Reference](#runtime-cli-reference)
- [Tooling](#tooling)
- [Editor Support](#editor-support)
- [Performance](#performance)
- [Security](#security)
- [Production Deployment](#production-deployment)
- [Testing](#testing)
- [Repository Structure](#repository-structure)
- [Documentation Index](#documentation-index)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

Nyx is a **multi-paradigm, compiled programming language** designed for high-performance computing, systems programming, and data science. It combines the expressiveness of Python with Rust-level memory safety and Julia-level scientific computing primitives — all without a garbage collector.

The project ships as a complete stack:

- **Native C runtime** (`native/nyx.c`) with interpreter, bytecode VM, and debugger
- **Self-hosting compiler** that compiles `.ny` source to standalone C programs
- **60+ standard library modules** spanning math, ML, crypto, networking, databases, and more
- **26 engine packages** for game development, GPU compute, web frameworks, AI, audio, rendering, and beyond
- **Package manager** (`nypm`) with dependency resolution, versioning, and a registry
- **VS Code extension** with syntax highlighting, snippets, icons, and debug adapter
- **Developer tools**: formatter (`nyfmt`), linter (`nylint`), debugger (`nydbg`)

### Language Comparison

| Feature | Nyx | Python | Rust | Julia |
|---------|-----|--------|------|-------|
| **Syntax** | C-style braces | Indentation | C-style braces | MATLAB-like |
| **Type System** | Static, inferred | Dynamic | Static, explicit | Dynamic, inferred |
| **Memory** | Ownership (no GC) | GC | Ownership | GC |
| **Performance** | Native (Rust-level) | Interpreted | Native | JIT-compiled |
| **Expressiveness** | High (Python-like) | Very High | Medium | Very High |
| **Safety** | Compile-time | Runtime | Compile-time | Runtime |
| **Scientific** | First-class | Libraries | Libraries | First-class |

---

## Key Features

- **Functional-first**: First-class functions, closures, pipelines, immutability by default
- **Object-oriented**: Classes, traits/interfaces, generics, inheritance
- **Safe by design**: Ownership-based memory management, borrow checking, lifetime inference — no GC
- **Zero-cost abstractions**: Iterator, Option, Result, Range, Borrow, Closure — all compiled away
- **Multi-execution**: Interpreter, bytecode VM (`--vm`), strict VM (`--vm-strict`), C codegen
- **Pattern matching**: `match`/`switch` expressions with guards
- **Async/await**: Structured concurrency with channels, task spawning, and work stealing
- **Rich type system**: Generics, union types, optional types (`T?`), type inference
- **Array comprehensions**: `[expr for x in iterable if cond]`
- **FFI**: Direct C interop with type-safe bindings
- **GPU support**: Optional CUDA, Vulkan, Metal, OpenCL, and ROCm backends
- **BLAS/LAPACK**: Optional OpenBLAS/MKL bindings for linear algebra

---

## Quick Start

### Linux / macOS

```bash
make
./build/nyx examples/fibonacci.ny
```

### Windows (PowerShell)

```powershell
.\scripts\build_windows.ps1 -Output .\build\nyx.exe
.\build\nyx.exe examples\fibonacci.ny
```

### Hello World

```nyx
# hello.ny
print("Hello, Nyx!");

fn greet(name) {
    return "Hello, " + name + "!";
}

print(greet("World"));
```

```bash
nyx hello.ny
```

---

## Language at a Glance

### Variables and Control Flow

```nyx
let x = 42;
let name = "Nyx";
let numbers = [1, 2, 3, 4, 5];

if (x > 10) {
    print("Large number");
} else {
    print("Small number");
}

for (item in numbers) {
    print(item);
}

# Dual-variable iteration
for (i, val in numbers) {
    print(i, "=>", val);
}
```

### Functions and Recursion

```nyx
fn fib(n) {
    if (n <= 1) {
        return n;
    }
    return fib(n - 1) + fib(n - 2);
}

print("Fibonacci(10) is:", fib(10));
```

### Classes and Objects

```nyx
class Point {
    fn init(self, x, y) {
        object_set(self, "x", x);
        object_set(self, "y", y);
    }
}

let p = new(Point, 3, 4);
print(p.x, p.y);
```

### Array Comprehensions

```nyx
let squares = [x * x for x in range(10) if x % 2 == 0];
print(squares);

# Dual-variable comprehensions
let obj = {a: 1, b: 2, c: 3};
let pairs = [k + "=" + str(v) for k, v in obj];
```

### Error Handling

```nyx
try {
    throw "something went wrong";
} catch (e) {
    print("Caught:", e);
}
```

### Modules and Imports

```nyx
module Math {
    fn add(a, b) {
        return a + b;
    }
}

# Modern syntax (unquoted - preferred)
import mylib;
import nymath;     # Built-in package, no file needed

# Legacy syntax (quoted - still supported)
import "mylib.ny";
import "nymath";
```

**See [Unquoted Module Syntax](UNQUOTED_IMPORT_SYNTAX.md) for full details.**

### Switch Statement

```nyx
switch (value) {
    case 1: { print("one"); }
    case 2: { print("two"); }
    default: { print("other"); }
}
```

---

## Architecture

Nyx follows a layered architecture:

```
Source (.ny) → Lexer → Parser → AST → [Type Checker / Borrow Checker]
                                         ↓
                              ┌──────────┴──────────┐
                              ↓                      ↓
                        Interpreter              VM Bytecode
                        (default)                (--vm flag)
                                                     ↓
                                                 Bytecode Cache
                                                     ↓
                                                 VM Execution
```

### Virtual Machine

The Nyx VM is a **stack-based bytecode interpreter** with:

- **~100+ opcodes** across 15 categories (stack, constants, locals, globals, control flow, arithmetic, comparison, logical, bitwise, objects, arrays, closures, async, error handling, types)
- **Bytecode format**: 32-byte header with magic `NYX\0`, version, flags, source hash, constant pool, function table, code section
- **Value representation**: Tagged union (`int64_t`, `double`, `void*`)
- **Object header**: 16 bytes (type tag + size + reference count)
- **Memory regions**: Stack (grows down) → Guard Page → Heap (grows up) → Static Data
- **Type tags**: NIL, BOOL, INT, FLOAT, STRING, ARRAY, OBJECT, FUNCTION, CLOSURE, CLASS, INSTANCE, MODULE, FUTURE, COROUTINE
- **Scheduler**: Work-stealing task scheduler with FIFO ready queue, configurable worker threads

### Execution Modes

| Mode | Flag | Description |
|------|------|-------------|
| Interpreter | (default) | Direct AST execution |
| Bytecode VM | `--vm` | Compiled to bytecode, faster for repeated runs |
| Strict VM | `--vm-strict` | Bytecode only, no fallback, deterministic |
| Parse-only | `--parse-only` | Syntax validation / linting |

---

## Type System

### Type Hierarchy

```
Type
├── Primitive: int, i8-i64, u8-u64, f32, f64, bool, char, str
├── Compound: [T] arrays, &[T] slices, (T1,T2) tuples, {K:V} objects, fn(T)->U functions
├── Reference: &T immutable, &mut T mutable
├── Optional: T?
├── Union: T1 | T2
└── User-defined: class, struct, enum, trait
```

- **Static typing** with smart type inference — rarely need explicit annotations for locals
- **No implicit conversions** (except widening `int` → `f64`)
- **Null safety**: `T?` types must be checked before use
- **Generics**: Monomorphized (no type erasure)
- **Traits**: Define shared behavior contracts for types

---

## Memory Model

Nyx uses **compile-time ownership and borrowing** (Rust-like) for memory safety without a garbage collector:

| Rule | Description |
|------|-------------|
| **Single Owner** | Every value has exactly one owner |
| **Move Semantics** | Assignment transfers ownership (unless `Copy` type) |
| **Borrowing** | `&T` (shared) and `&mut T` (exclusive) references |
| **RAII** | Destructors called deterministically at scope end |
| **No GC** | Zero garbage collection pauses |

**Copy types** (auto-copied on assignment): `int`, `bool`, `f64`, `char`, all primitives.
**Move types** (ownership transferred): `String`, arrays, objects, user-defined types.

Smart pointers available in stdlib: `Rc<T>` (single-threaded), `Arc<T>` (thread-safe).

---

## Concurrency

- **Async/await** with structured concurrency
- **Channels** for safe message passing between tasks
- **Task spawning** with `spawn` and lightweight green threads
- **Work-stealing scheduler** for load balancing
- **Send + Sync traits** enforced at compile-time for thread safety
- **Bounded worker pools** with admission semaphores and backpressure (HTTP 503 on queue-full)
- **Multi-process locking**: `fcntl.flock` (Unix), `msvcrt.locking` (Windows)

```nyx
async fn fetch(url: str) -> Response {
    let response = await http_get(url);
    return response;
}

let (tx, rx) = channel();
spawn(async {
    tx.send("Hello from task");
});
let msg = await rx.recv();
```

---

## Standard Library

Nyx ships with **60+ standard library modules** in `stdlib/`:

| Category | Modules |
|----------|---------|
| **Core** | `types`, `class`, `ffi`, `c`, `io`, `string`, `math`, `json`, `time` |
| **Data Structures** | `collections`, `algorithm`, `cache`, `regex`, `xml`, `serialization` |
| **Networking** | `http`, `socket`, `network`, `redis` |
| **Concurrency** | `async`, `distributed`, `process` |
| **Cryptography** | `crypto`, `jwt` |
| **ML / AI** | `nn`, `tensor`, `autograd`, `nlp`, `science`, `experiment`, `dataset`, `feature_store`, `train`, `serving`, `mlops` |
| **Scientific** | `blas`, `fft`, `sparse`, `optimize`, `precision`, `symbolic` |
| **Web** | `web`, `governance` |
| **Database** | `database`, `hub` |
| **Dev Tools** | `debug`, `bench`, `test`, `log`, `monitor`, `metrics`, `formatter`, `lsp`, `parser`, `cli`, `ci` |
| **Other** | `gui`, `game`, `config`, `cron`, `compress`, `state_machine`, `validator`, `visualize`, `systems` |

### Built-in Packages (importable without files)

```nyx
import "nymath";     # abs, min, max, clamp, pow, sum
import "nyarrays";   # first, last, sum, enumerate
import "nyobjects";  # merge, get_or
import "nyjson";     # parse, stringify
import "nyhttp";     # get, text, ok
```

---

## Engine Ecosystem

The `engines/` directory contains **26 specialized engine packages**, each with a `ny.pkg` manifest:

| Engine | Description |
|--------|-------------|
| **nycore** | Foundation: memory allocators (arena/pool/frame), work-stealing scheduler, task graph, archetype ECS, platform abstraction, SIMD dispatch |
| **nyai** | NPC Intelligence: behavior trees + GOAP, crowd simulation, combat AI, police systems, social simulation, perception stack |
| **nyanim** | Animation: full-body IK, motion matching, facial simulation, blend trees, locomotion synthesis, retargeting |
| **nyarray** | Scientific Computing: multi-dimensional arrays, linear algebra, signal processing, optimization, statistics |
| **nyaudio** | 3D Audio: HRTF spatial audio, occlusion, Doppler, convolution reverb, dynamic soundtrack, voice chat |
| **nyautomate** | Automation: RPA, task scheduling, workflow management, GUI/browser/Excel/PDF/email automation |
| **nybuild** | Build System: dependency graph, build cache, incremental compilation, testing, formatting, linting, packaging |
| **nycrypto** | Cryptography: cipher algorithms, hash functions, digital signatures, key exchange, encoding |
| **nydatabase** | Database: SQL query builder, ORM, connection pooling, migrations, transactions (SQLite, PostgreSQL, MySQL) |
| **nydoc** | Documents: LaTeX/PDF/HTML/Markdown generation, charts, tables, report builder |
| **nygame** | Game Development: physics, AI, characters, weapons, vehicles, multiplayer, native engine sync bridges |
| **nygpu** | GPU Compute: CUDA, Vulkan, Metal, ROCm, device management, GPU memory, kernel compilation, tensor ops |
| **nygui** | GUI Framework: widgets, layouts, canvas, menus, dialog boxes |
| **nyhttp** | HTTP: HTTP/1.1, HTTP/2, HTTP/3 (QUIC), TLS 1.3, mTLS, radix-tree routing, middleware, WebSocket, reverse proxy, load balancing |
| **nylogic** | Declarative Game Logic: rule DSL, graph orchestration, AI-assisted rule generation, hot mutation |
| **nyls** | Language Server: full LSP implementation with completion, hover, go-to-definition, rename, diagnostics, type checking |
| **nymedia** | Multimedia: audio/video/image processing, 2D/3D graphics, camera, screen capture, encoding, streaming |
| **nyml** | Machine Learning: neural networks, optimizers, datasets, preprocessing, training, pre-built models |
| **nynet** | Multiplayer Infrastructure: authoritative server, deterministic sync, anti-cheat, scaling |
| **nyrender** | Rendering engine |
| **nyphysics** | Physics simulation |
| **nyworld** | World streaming |
| **nysec** | Security engine |
| **nyserver** | Server framework |
| **nyweb** | Web framework |
| **nyui** | UI framework |

Install any engine via `nypm install <EngineName>`.

---

## Package Manager (nypm)

Nyx includes a full-featured package manager:

```bash
nypm init my-project          # Initialize new package
nypm install <package>        # Install a package
nypm add <pkg@version>        # Add specific version
nypm search <query>           # Search registry
nypm list                     # List installed packages
nypm remove <package>         # Remove package
nypm update                   # Update packages
nypm doctor                   # Check setup health
nypm publish <path>           # Publish to registry
```

- **Package manifest**: `ny.pkg` (TOML-like format)
- **Lock file**: `ny.lock` for reproducible builds
- **Modules directory**: `nyx_modules/`
- **Registry**: `registry.nyxlang.dev`
- **Version resolution**: Semver with caret (`^`) and tilde (`~`) ranges

Shell and PowerShell wrappers available: `scripts/nypm.sh`, `scripts/nypm.ps1`.

---

## Compiler Bootstrapping

Nyx follows a disciplined **4-stage bootstrap** path toward self-hosting:

| Stage | Status | Description |
|-------|--------|-------------|
| **Stage 0** | Completed | C implementation (`native/nyx.c`) → native `nyx` executable |
| **Stage 1** | Completed | Expand C runtime to support writing compilers in `.ny` |
| **Stage 2** | Completed | First `.ny` compiler (`compiler/bootstrap.ny`) — compiles arithmetic expressions to C |
| **Stage 3** | Completed | Self-hosting compiler (`compiler/v3_seed.ny`) — deterministic rebuild loop |

### Self-Hosting Verification

The v3 self-hosting compiler passes a deterministic rebuild check:

```
Stage 1: nyx → compiler_stage1.c
Stage 2: compiler_stage1 --emit-self → compiler_stage2.c
Stage 3: compiler_stage2 --emit-self → compiler_stage3.c
Verify:  stage1.c == stage2.c == stage3.c  ✓
```

The compiled output covers: imports, functions, arrays, objects, classes, modules, typealias, try/catch/throw, loops, comprehensions, and all v4 builtins.

---

## Version History

| Version | Milestone | Key Additions |
|---------|-----------|--------------|
| **v0** | Native Runtime | Integer literals, arithmetic, `print`, comments, native C build |
| **v1** | Compiler-Capable | Variables, if/else, functions, strings, arrays, file I/O, imports |
| **v2** | First .ny Compiler | Bootstrap compiler in Nyx, `argc()`/`argv()` builtins |
| **v3** | Self-Hosting | Self-hosting compiler, deterministic rebuild, direct C codegen for full syntax |
| **v4** | Runtime Expansion | While/for loops, comprehensions, `&&`/`||`/`??`/`%`, switch/case, classes, modules, VM bytecode, linter/formatter, allocation guards, compatibility hooks |

---

## Build System

### Build Requirements

| Platform | Requirements |
|----------|-------------|
| **Linux/macOS** | `make`, C compiler (`gcc`, `clang`) |
| **Windows** | PowerShell, C compiler (clang preferred, gcc or MSVC `cl` fallback) |

### Makefile (Linux/macOS)

```bash
make              # Build to build/nyx
make clean        # Clean build artifacts
```

Compiler flags: `-O2 -std=c99 -Wall -Wextra -Werror`

### Windows Build Script

```powershell
.\scripts\build_windows.ps1 -Output .\build\nyx.exe
```

The script auto-detects available C compilers (clang → gcc → cl) and resource compilers for Windows executable icons.

### Optional Compile Flags

| Flag | Description |
|------|-------------|
| `-DNYX_BLAS` | Enable OpenBLAS/MKL for linear algebra (`-lopenblas`) |
| `-DNYX_CUDA` | Enable NVIDIA GPU acceleration (`-lcuda -lcublas -lcudart`) |
| `-DNYX_OPENCL` | Enable OpenCL GPU acceleration (`-lOpenCL`) |

---

## Runtime CLI Reference

```
Usage: nyx [options] <file.ny> [args...]
```

| Flag | Description |
|------|-------------|
| `--vm` | Execute through bytecode VM |
| `--vm-strict` | Bytecode-only, no interpreter fallback |
| `--parse-only` / `--lint` | Syntax validation only |
| `--trace` | Statement trace mode |
| `--debug` | Enable in-process debugger |
| `--break <lines>` | Set breakpoints (comma-separated line numbers) |
| `--step` | Step-by-step execution |
| `--step-count N` | Step N statements at a time |
| `--max-alloc N` | Maximum bytes allocated (runaway protection) |
| `--max-steps N` | Maximum execution steps |
| `--max-call-depth N` | Maximum call stack depth |
| `--version` | Print version and exit |

### Builtins

Core: `print`, `len`, `type`, `str`, `int`, `range`, `abs`, `min`, `max`, `clamp`, `sum`, `all`, `any`
I/O: `read`, `write`, `argc`, `argv`
Type checks: `type_of`, `is_int`, `is_bool`, `is_string`, `is_array`, `is_function`, `is_null`
Objects: `object_new`, `object_set`, `object_get`, `keys`, `values`, `items`, `has`
Classes: `new`, `class_new`, `class_with_ctor`, `class_set_method`, `class_name`
Compat: `lang_version`, `require_version`

---

## Tooling

| Tool | Shell | PowerShell | Purpose |
|------|-------|------------|---------|
| **nypm** | `scripts/nypm.sh` | `scripts/nypm.ps1` | Package manager |
| **nyfmt** | `scripts/nyfmt.sh` | `scripts/nyfmt.ps1` | Code formatter |
| **nylint** | `scripts/nylint.sh` | `scripts/nylint.ps1` | Linter |
| **nydbg** | `scripts/nydbg.sh` | `scripts/nydbg.ps1` | Debugger |

```bash
# Format all files
./scripts/nyfmt.sh .

# Check formatting without modifying
./scripts/nyfmt.sh --check .

# Lint project
./scripts/nylint.sh .

# Debug a program
./scripts/nydbg.sh examples/fibonacci.ny
```

---

## Editor Support

### VS Code Extension — `nyx-language` v3.3.3

The Nyx VS Code extension provides:

- **Syntax highlighting** via TextMate grammar (`.ny`, `.nx` files)
- **Code snippets** for common patterns
- **File icon theme** with Nyx-branded icons
- **Language configuration** (bracket matching, auto-closing, comments)
- **Debug adapter** for integrated debugging

Install from packaged VSIX:

```bash
code --install-extension editor/vscode/nyx-language/nyx-language-3.0.3.vsix
```

### Language Server (nyls)

The `nyls` engine provides a full LSP implementation with:
completion, hover, go-to-definition, type definition, find references, rename, code actions, document formatting, signature help, diagnostics, and workspace symbols.

---

## Performance

### Benchmark Comparison

| Benchmark | Nyx | Python | Rust | Go |
|-----------|-----|--------|------|-----|
| Fibonacci (iterative) | 0.1 ms | 5 ms | 0.05 ms | 0.2 ms |
| Fibonacci (recursive) | 2 ms | 100 ms | 1 ms | 5 ms |
| Prime Sieve (1M) | 10 ms | 200 ms | 5 ms | 15 ms |
| Matrix Multiply (100×100) | 2 ms | 50 ms | 1.5 ms | 3 ms |
| JSON Parse | 1 ms | 10 ms | 0.5 ms | 2 ms |
| Hello World startup | 5 ms | 50 ms | 2 ms | 10 ms |

### Memory Footprint

| Component | Nyx | Python | Rust |
|-----------|-----|--------|------|
| Runtime (minimal) | 2 MB | 15 MB | 1.5 MB |
| Per-integer | 8 B | 28 B | 8 B |
| Per-string (short) | 32 B | 49 B | 24 B |
| Per-closure | 48 B | 64 B | 32 B |

### Zero-Cost Abstractions

| Abstraction | Runtime Cost | Memory Overhead |
|-------------|-------------|-----------------|
| Iterator | 0 cycles | 0 bytes |
| Option\<T\> | 0 cycles | 0 bytes |
| Result\<T,E\> | 0 cycles | 0 bytes |
| Range | 0 cycles | 0 bytes |
| Borrow | 0 cycles | 0 bytes |
| Closure | 0 cycles | 0 bytes |

**Summary**: 10-100x faster than Python, 2-5x slower than Rust, comparable to Go.

---

## Security

### Multi-Layered Security Model

1. **Compile-time**: Borrow checking, lifetime inference, type safety, memory safety (no null derefs, no buffer overflows)
2. **Runtime**: Configurable bounds checking (`NYX_SAFETY_ENABLED`), null safety, overflow detection
3. **Hardening**: Hardened allocator, stack canaries, position-independent executable (PIE)
4. **Web runtime**: CSRF protection, replay detection, rate limiting, strict content-type, payload size caps

### Runtime Safety Guards

| Guard | Flag | Purpose |
|-------|------|---------|
| Allocation limit | `--max-alloc N` | Prevent memory exhaustion |
| Step limit | `--max-steps N` | Stop runaway scripts |
| Call depth | `--max-call-depth N` | Prevent stack overflow |

### Reporting Vulnerabilities

Do not open public issues for security bugs. Send private reports to project maintainers. See `docs/SECURITY.md` for the full disclosure policy; triage within 72 hours, critical patches within 7 days.

---

## Production Deployment

### Observability

Nyx runtime includes native observability endpoints:

| Endpoint | Description |
|----------|-------------|
| `GET /__nyx/metrics` | Request counts, latency, error rate, memory, worker utilization |
| `GET /__nyx/errors` | Recent error log with bounded retention |
| `GET /__nyx/health` | Health status (degrades on high load / errors) |
| `GET /__nyx/plugins` | Plugin status |

### Distributed Mode

- Pluggable coordination API with `StateProvider.transaction(namespace, updater)`
- Built-in providers: `InMemoryStateProvider`, `FileStateProvider`
- Coordinated rate limiting, replay dedupe, and shared state across instances
- Horizontal scaling behind L4/L7 load balancers

### Scaling

- Bounded worker-pool with admission semaphore and backpressure
- 503 on queue-full, 504 on timeout — preserving low tail latency
- Per-connection WebSocket failure isolation
- Atomic persistence: temp-write → fsync → rename

---

## Testing

### Test Suites

```bash
# Version milestone tests
./scripts/test_v0.sh           # v0: native runtime basics
./scripts/test_v1.sh           # v1: variables, functions, control flow
./scripts/test_v2.sh           # v2: first .ny compiler
./scripts/test_v3_start.sh     # v3: self-hosting compiler
./scripts/test_v4.sh           # v4: runtime expansion

# Quality gates
./scripts/test_compatibility.sh
./scripts/test_ecosystem.sh
./scripts/test_registry.sh
./scripts/test_runtime_hardening.sh
./scripts/test_sanitizers.sh         # AddressSanitizer, UBSan
./scripts/test_vm_consistency.sh
./scripts/test_fuzz_vm.sh            # Fuzz testing
./scripts/test_soak_runtime.sh       # Soak / stress testing

# Production release gate
./scripts/test_production.sh                       # Linux/macOS
.\scripts\test_production.ps1 -VmCases 300         # Windows
```

---

## Repository Structure

```
native/          C runtime implementation (nyx.c)
compiler/        Bootstrap and self-hosting compiler sources
stdlib/          60+ standard library modules (.ny)
engines/         26 engine packages (nycore, nyml, nygpu, nyweb, ...)
examples/        Runnable example programs
language/        Grammar (EBNF), type system, ownership, concurrency specs
editor/vscode/   VS Code extension (syntax, snippets, icons, debug adapter)
scripts/         Build, test, packaging, and developer tools
docs/            Specifications, guides, and architecture documents
tests/           Test suites and fixtures
packages/        Package registry data
```

---

## Documentation Index

| Document | Description |
|----------|-------------|
| `docs/NYX_LANGUAGE_SPEC.md` | Core language specification |
| `docs/NYX_LANGUAGE_SPECIFICATION_V2.md` | V2 complete specification |
| `docs/LANGUAGE_SPEC.md` | Bootstrap draft spec (v4 runtime) |
| `docs/NYX_V1_ARCHITECTURE.md` | V1 architecture with formal grammar |
| `docs/VM_SPEC.md` | Virtual machine and bytecode specification |
| `docs/BREAFING_OF_NYX.md` | Complete practical reference |
| `docs/BOOTSTRAP.md` | Compiler bootstrapping plan |
| `docs/ECOSYSTEM.md` | Package ecosystem and production readiness |
| `docs/BENCHMARKS.md` | Performance benchmark framework |
| `docs/RUST_LEVEL.md` | Rust-level safety guarantees |
| `docs/USER_GUIDE.md` | User guide |
| `docs/SECURITY.md` | Security policy |
| `docs/V0.md` – `docs/V4.md` | Version milestone documentation |
| `docs/memory_model.md` | Memory model specification |
| `docs/concurrency_model.md` | Concurrency model |
| `docs/distributed_mode.md` | Distributed coordination |
| `docs/observability.md` | Observability endpoints and tracing |
| `docs/scaling_guide.md` | High-traffic scaling guide |
| `docs/production_deployment_guide.md` | Production deployment reference |
| `language/grammar.ebnf` | Formal EBNF grammar |
| `language/types.md` | Type system reference |
| `language/ownership.md` | Ownership and borrowing reference |

---

## Contributing

Before opening PRs, run the platform-appropriate production gates:

```bash
# Linux/macOS
./scripts/test_production.sh

# Windows
.\scripts\test_production.ps1 -VmCases 300
```

If you modify runtime or compiler behavior, also run consistency and fuzz suites:

```bash
./scripts/test_vm_consistency.sh
./scripts/test_fuzz_vm.sh
./scripts/test_sanitizers.sh
```

See `CONTRIBUTING.md` for detailed contribution guidelines.

---

## License

Nyx is licensed under a **custom no-contribution license**:

✅ **You CAN:**
- Download and use the software freely
- Experiment and modify locally for personal use
- Use in personal, educational, or commercial projects
- Report bugs and request features via GitHub Issues

❌ **You CANNOT:**
- Push or commit changes to the repository
- Create pull requests or contribute code
- Redistribute modified versions
- Fork for public distribution

Copyright (c) 2024-2026 Surya Sekhar Roy. All Rights Reserved.

See the [LICENSE](LICENSE) file for full terms and conditions.
