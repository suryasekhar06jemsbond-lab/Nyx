# Nyx Language Research Reference

**Document Type:** Full technical reference for publication and research use  
**Date:** 2026-02-20  
**Primary runtime validated:** `nyx 0.6.13` (`./nyx --version`)  
**Scope:** Language syntax, semantics, runtime/toolchain, standard library, ecosystem modules, and implementation status matrix.

---

## 1. Executive Summary

Nyx is a multi-backend language project with:

1. A **native runtime binary** (`./nyx`) that executes `.ny` and `.nx` programs.
2. A **Python implementation stack** under `src/` (`lexer`, `parser`, `interpreter`) used for parser/interpreter development and tests.
3. A **Python runtime bridge** (`nyx_runtime.py`) that transpiles Nyx-like syntax to Python for runtime framework integration.

The repository also includes:

1. A large standard library (`stdlib/`, 13,163 LOC in current tree).
2. 20+ engine packages in `engines/`.
3. Tooling wrappers (`nypm`, `nyfmt`, `nylint`, `nydbg`, `cy*`).
4. Versioned milestone docs (`docs/V0.md` ... `docs/V4.md`).

This reference explicitly separates:

1. **Verified runtime behavior** (`nyx 0.6.13` tested directly).
2. **Specified/declared behavior** from grammar/spec docs.
3. **Backend-dependent features** not uniformly implemented.

---

## 2. Source Of Truth Used For This Reference

Primary files used:

1. `docs/LANGUAGE_SPEC.md`
2. `docs/NYX_LANGUAGE_SPECIFICATION_V2.md`
3. `language/grammar.ebnf`
4. `src/token_types.py`
5. `src/lexer.py`
6. `src/parser.py`
7. `src/interpreter.py`
8. `nyx_runtime.py`
9. `docs/V0.md`, `docs/V1.md`, `docs/V2.md`, `docs/V3.md`, `docs/V4.md`
10. `stdlib/*.ny`
11. `engines/*/ny.pkg`

Runtime verification was executed directly via `./nyx` on representative scripts and targeted feature probes.

---

## 3. Language Identity And File Types

### 3.1 File extensions

1. Primary: `.ny`
2. Legacy/compatible in native runtime: `.nx`

Both are executable by the current runtime (`./nyx examples/hello.nx` and `./nyx main.ny` were validated).

### 3.2 Comment syntax (native runtime)

1. Supported: `#` line comments
2. Not supported in native runtime: `//` comments, `/* ... */` block comments

### 3.3 Statement termination

1. `;` is required for non-block statements in native runtime.
2. Block forms (`if`, `while`, `for`, `fn`, `class`, `module`, `switch`, `try`) use braces.

---

## 4. Verified Core Syntax (Nyx 0.6.13)

### 4.1 Literals

Supported in native runtime:

1. Integer literals: `0`, `1`, `42`
2. String literals (double quotes): `"hello"`
3. Booleans: `true`, `false`
4. Null: `null`
5. Arrays: `[1, 2, 3]`
6. Objects: `{a: 1, "b": 2}`

Not supported in native runtime (in tested build):

1. Float literals (`1.5`)
2. Hex/octal/binary integer literals (`0xFF`, `0o77`, `0b1010`)
3. Single-quoted strings (`'x'`)

### 4.2 Expressions and operators

Supported in native runtime:

1. Arithmetic: `+ - * / %`
2. Comparisons: `== != < > <= >=`
3. Logical: `&& || !`
4. Null coalescing: `??`
5. Index access: `arr[i]`, `obj["k"]`
6. Member access: `obj.key`
7. Assignment targets:
- `name = value`
- `obj.key = value`
- `arr[i] = value`

Not supported in native runtime (tested build):

1. Power operator: `**`
2. Floor divide: `//`
3. Bitwise operators: `& | ^ ~ << >>`
4. Compound assignments: `+= -= *= /= %= //=`

### 4.3 Control flow

Supported in native runtime:

1. `if / else if / else`
2. `while`
3. `for (item in iterable)`
4. `for (k, v in iterable)`
5. `break`
6. `continue`
7. `switch / case / default` with `:` and block bodies

### 4.4 Functions

Supported:

1. Named declarations:

```nyx
fn add(a, b) {
    return a + b;
}
```

2. Recursion
3. First-class passing of named functions

Behavior note:

1. Function implicit return is **not** enabled in native runtime; no explicit `return` yields `null`.

### 4.5 Exceptions

Supported in native runtime:

1. `throw expr;`
2. `try { ... } catch (e) { ... }`

Not supported in native runtime (tested):

1. `finally`
2. `except` keyword alias

### 4.6 Declarations and namespace constructs

Supported in native runtime:

1. `let name = expr;`
2. `class Name { ... }`
3. `module Name { ... }`
4. `typealias Name = expr;` (parsed/no-op compatibility construct)
5. `import "relative_path.ny";`

Not supported in native runtime (tested):

1. `pub` modifier
2. `use` directive alias
3. Type annotations in declarations/parameters (`let x: Int`, `fn f(x: Int) -> Int`)
4. Class inheritance syntax (`class B: A`)
5. Anonymous function literals (`fn(x) { ... }` as expression)

### 4.7 Comprehensions

Supported in native runtime:

1. Single-variable:

```nyx
let odds = [x for x in arr if x % 2 == 1];
```

2. Dual-variable:

```nyx
let vals = [i + x for i, x in arr if i > 0];
```

---

## 5. Verified Native Runtime Semantics

### 5.1 Top-level expression output

Top-level expression statements print their non-null result.

Example:

```nyx
1 + 2;
```

Output:

```text
3
```

### 5.2 Truthiness

Observed behavior:

1. `null` is falsey
2. `true` is truthy
3. `false` is falsey
4. Non-null values are truthy in condition checks

### 5.3 Loop iteration model

1. Arrays in dual-for yield `(index, value)`.
2. Objects in dual-for yield `(key, value)`.
3. Single-for over object yields key values.

### 5.4 Import behavior

1. File-path imports are supported.
2. Relative import paths are resolved from execution context.
3. Import-based helper files can expose functions directly for subsequent calls.

---

## 6. Built-ins (Validated In `nyx 0.6.13`)

The following built-ins were directly exercised and confirmed in runtime tests.

### 6.1 Core I/O and process

1. `print(...)`
2. `read(path)`
3. `write(path, value)`
4. `argc()`
5. `argv(index)`

### 6.2 Type and conversion

1. `type(value)`
2. `str(value)`
3. `int(value)`
4. `type_of(value)`
5. `is_int(value)`
6. `is_bool(value)`
7. `is_string(value)`
8. `is_array(value)`
9. `is_function(value)`
10. `is_null(value)`

### 6.3 Collections and numerics

1. `len(value)`
2. `push(array, value)`
3. `pop(array)`
4. `range(...)`
5. `abs(x)`
6. `min(a, b)`
7. `max(a, b)`
8. `clamp(v, lo, hi)`
9. `sum(array)`
10. `all(array_bool)`
11. `any(array_bool)`

### 6.4 Object helpers

1. `object_new()`
2. `object_set(obj, key, value)`
3. `object_get(obj, key)`
4. `keys(obj)`
5. `values(obj)`
6. `items(obj)`
7. `has(obj, key)`

### 6.5 Class helpers

1. `new(class_obj, ...)`
2. `class_new(name)`
3. `class_with_ctor(name, ctor)`
4. `class_set_method(cls, name, fn)`
5. `class_name(cls)`
6. `class_instantiate0/1/2(...)`
7. `class_call0/1/2(...)`

### 6.6 Compatibility/version

1. `lang_version()`
2. `require_version(version_string)`

### 6.7 Documented but build-dependent

`docs/LANGUAGE_SPEC.md` documents builtin packages such as `nymath`, `nyarrays`, `nyobjects`, `nyjson`, `nyhttp`, but these were not available in the tested native runtime build via `import "..."`. Treat these as implementation-dependent and verify per distribution.

---

## 7. Runtime CLI And Execution Modes

Native runtime usage string:

```text
Usage: nyx [--trace] [--parse-only|--lint] [--vm|--vm-strict] [--max-alloc N] [--max-steps N] [--max-call-depth N] [--debug] [--break lines] [--step] [--step-count N] [--debug-no-prompt] [--version] <file.nx> [args...]
```

### 7.1 Flags

1. `--version`: prints runtime version (`0.6.13` validated)
2. `--trace`: statement trace output
3. `--parse-only`: parse/lint mode
4. `--lint`: alias of parse-only mode
5. `--vm`: VM execution mode
6. `--vm-strict`: strict VM mode
7. `--max-alloc N`: allocation guard (implementation-dependent behavior)
8. `--max-steps N`: step guard (validated)
9. `--max-call-depth N`: recursion guard (validated)
10. `--debug`: interactive debug mode
11. `--break lines`: line breakpoints
12. `--step`: step mode
13. `--step-count N`: limited stepping
14. `--debug-no-prompt`: debug without interactive prompt

### 7.2 Guard behavior examples

1. Step guard violation returns error like `max step count exceeded`.
2. Call depth guard violation returns error like `max call depth exceeded`.

---

## 8. Language Backend Model (Important For Researchers)

Nyx currently exists as a multi-backend ecosystem, not a single parser/runtime implementation.

### 8.1 Backend A: native runtime (`./nyx`)

1. Most production-like CLI/runtime path.
2. Supports broad v4-style control flow (`switch`, `try/catch`, comprehensions, class/module/typealias).
3. Does not currently support several tokens listed in parser grammar docs (e.g., typed parameters in tested build).

### 8.2 Backend B: `src/` parser/interpreter stack

Key files:

1. `src/token_types.py`
2. `src/lexer.py`
3. `src/parser.py`
4. `src/interpreter.py`

Characteristics:

1. Lexer supports a richer token set (floats, hex, bitwise, async keywords, etc.).
2. Parser supports a defined AST subset (let, return, class, for-in, print, function literal, if, while, arrays/objects, calls, index/member, assignment).
3. Interpreter currently handles a practical subset and includes integration points for web/UI runtime objects.

### 8.3 Backend C: `nyx_runtime.py` bridge

1. Transforms Nyx-like code into Python and executes it.
2. Exposes extensive runtime framework classes (`nyweb`, `nyui`, virtual DOM, reactive state, middleware, websocket, stores).
3. Includes rewrite/compatibility behavior configured by `.nyx/stability.json`.

---

## 9. Formal Grammar And Keyword Universe

The formal grammar in `language/grammar.ebnf` defines a larger language surface than any single runtime backend currently enforces uniformly.

### 9.1 Keyword groups from grammar/token definitions

1. Declaration: `fn`, `let`, `class`, `module`, `typealias`
2. Control flow: `if`, `else`, `switch`, `case`, `default`, `while`, `for`, `in`, `break`, `continue`, `return`
3. Error handling: `try`, `catch`, `except`, `finally`, `raise`, `throw`, `assert`
4. OOP/context: `new`, `self`, `super`
5. Async: `async`, `await`, `yield`, `with`
6. Module/import: `import`, `from`, `as`
7. Special: `null`, `true`, `false`, `pass`

### 9.2 Grammar scope includes

1. Function and type annotations
2. Rich operator precedence tiers
3. Union/reference/generic types
4. Async and yield forms
5. Comprehensions and object creation patterns

Use this grammar as a **spec target** and verify feature support per backend.

---

## 10. Standard Library (`stdlib/`) Current Inventory

Current total stdlib LOC: **13,163**.

### 10.1 Core modules present

1. `stdlib/algorithm.ny` (1,178 LOC)
2. `stdlib/async.ny` (603 LOC)
3. `stdlib/c.ny` (291 LOC)
4. `stdlib/class.ny` (94 LOC)
5. `stdlib/cli.ny` (374 LOC)
6. `stdlib/config.ny` (479 LOC)
7. `stdlib/ffi.ny` (228 LOC)
8. `stdlib/fft.ny` (429 LOC)
9. `stdlib/formatter.ny` (411 LOC)
10. `stdlib/io.ny` (500 LOC)
11. `stdlib/json.ny` (926 LOC)
12. `stdlib/lsp.ny` (488 LOC)
13. `stdlib/math.ny` (3,252 LOC)
14. `stdlib/string.ny` (2,212 LOC)
15. `stdlib/systems.ny` (372 LOC)
16. `stdlib/test.ny` (281 LOC)
17. `stdlib/time.ny` (1,002 LOC)
18. `stdlib/types.ny` (28 LOC)

### 10.2 Functional coverage highlights

1. Algorithms: sorting/searching, graph ops, dynamic programming, string-search algorithms.
2. Math: constants, trig/hyperbolic/special functions, number theory, interpolation, numerical methods.
3. String: transformations, matching, NLP-oriented helpers, similarity metrics.
4. Async: event loop, futures/promises, task utilities, semaphore/lock/queue abstractions.
5. IO/config/json/time: practical application-level utilities.
6. Systems/ffi/c: low-level interop and memory/system primitives.

### 10.3 Package bootstrap

`stdlib/__init__.ny` exposes package-level modules and currently reports:

1. `VERSION = "2.0.0"`
2. `IMPLEMENTATION = "nyx"`

---

## 11. Engine Ecosystem (`engines/`) Current Inventory

Current engine directories:

1. `nyarray`
2. `nyautomate`
3. `nybuild`
4. `nycrypto`
5. `nydatabase`
6. `nydb`
7. `nydoc`
8. `nygame`
9. `nygpu`
10. `nygui`
11. `nyhttp`
12. `nyls`
13. `nymedia`
14. `nyml`
15. `nynetwork`
16. `nypm`
17. `nyqueue`
18. `nysci`
19. `nysec`
20. `nyserver`
21. `nysystem`
22. `nyui`
23. `nyweb`

These engine manifests (`engines/*/ny.pkg`) declare broad coverage across:

1. Web/backend infrastructure
2. Database and ORM
3. Scientific computing and GPU
4. ML/AI tooling
5. Security and automation
6. Build, package, and language server infrastructure

---

## 12. Toolchain Commands And Packaging

### 12.1 Core command wrappers

1. `nyx` / `cy` / `cyber`
2. `scripts/nypm.sh` and `scripts/nypm.ps1`
3. `scripts/nyfmt.sh` and `scripts/nyfmt.ps1`
4. `scripts/nylint.sh` and `scripts/nylint.ps1`
5. `scripts/nydbg.sh` and `scripts/nydbg.ps1`

### 12.2 Package/project files

1. `nyproject.toml` (unified project config)
2. `ny.pkg` (package manifest)
3. `ny.lock` (lock file)
4. `ny.registry` (registry index)

### 12.3 `nypm` command surface (from `scripts/nypm.sh`)

1. `init`
2. `add`
3. `add-remote`
4. `dep`
5. `version`
6. `remove`
7. `list`
8. `path`
9. `search`
10. `publish`
11. `registry`
12. `resolve`
13. `lock`
14. `verify-lock`
15. `install`
16. `doctor`

---

## 13. Verified Example Snippets

### 13.1 If/else if/else

```nyx
let x = 2;
if (x == 1) {
    print("one");
} else if (x == 2) {
    print("two");
} else {
    print("other");
}
```

### 13.2 For-in (single and dual)

```nyx
let arr = [5, 6, 7];
for (v in arr) {
    print(v);
}

for (i, v in arr) {
    print(i);
    print(v);
}
```

### 13.3 Switch/case/default

```nyx
switch (2) {
    case 1: { print("one"); }
    case 2: { print("two"); }
    default: { print("other"); }
}
```

### 13.4 Try/catch/throw

```nyx
try {
    throw "boom";
} catch (e) {
    print(e);
}
```

### 13.5 Class + constructor + method

```nyx
class Point {
    fn init(self, x, y) {
        object_set(self, "x", x);
        object_set(self, "y", y);
    }

    fn sum(self) {
        return object_get(self, "x") + object_get(self, "y");
    }
}

let p = new(Point, 3, 4);
print(p.sum());
```

### 13.6 Module declaration

```nyx
module Math {
    fn add(a, b) {
        return a + b;
    }
}

print(Math.add(7, 8));
```

### 13.7 Array comprehension

```nyx
let arr = [1, 2, 3, 4, 5];
let odds = [x for x in arr if x % 2 == 1];
print(odds[0]);
```

---

## 14. Version Milestone Timeline (Repository Docs)

1. `V0`: native runtime baseline
2. `V1`: compiler-capable runtime expansion
3. `V2`: first `.ny` compiler stage
4. `V3`: self-hosting compiler flow
5. `V4`: runtime expressiveness/tooling hardening expansion

See:

1. `docs/V0.md`
2. `docs/V1.md`
3. `docs/V2.md`
4. `docs/V3.md`
5. `docs/V4.md`

---

## 15. Compatibility Matrix (Research-Critical)

Legend:

1. `Yes`: implemented and observed or clearly implemented in source
2. `Partial`: parse-only/no-op/backend-specific or unverified in runtime
3. `No`: rejected in tested native runtime

| Feature | Native `nyx 0.6.13` | `src/` parser/interpreter | `nyx_runtime.py` bridge |
|---|---|---|---|
| `let` declarations | Yes | Yes | Yes |
| Integer literals | Yes | Yes | Yes |
| Float literals | No (tested) | Yes | Yes (Python numeric) |
| Hex/bin/oct literals | No (tested) | Yes | Partial |
| Double-quoted strings | Yes | Yes | Yes |
| Single-quoted strings | No (tested) | Yes | Yes |
| `if/else if/else` | Yes | Yes | Yes |
| `while` | Yes | Yes | Yes |
| `for (x in y)` | Yes | Yes | Yes |
| `for (k, v in y)` | Yes | Partial (parser/runtime mismatch) | Partial |
| `switch/case/default` | Yes | No | Partial |
| `try/catch` | Yes | No | Partial (Python exception mapping) |
| `finally` | No (tested) | No | Yes (Python path) |
| `class` | Yes | Parse support | Yes |
| Class inheritance syntax | No (tested) | Parse support (`:`) | Partial |
| `module` | Yes | No | Partial |
| `typealias` | Yes (compat/no-op) | No | Partial |
| Anonymous `fn(...)` literal expr | No (tested) | Yes | Partial |
| Array comprehension | Yes | No | Partial |
| `async/await` syntax | No (tested) | Token-level only | Partial/Yes (Python-backed) |
| Type annotations (`: T`, `-> T`) | No (tested) | Skipped/ignored in parser | Partial |
| Power `**` | No (tested) | Token support | Partial |
| Bitwise ops | No (tested) | Token support | Partial |
| Compound assign (`+=`) | No (tested) | Token support | Partial |

Use this matrix when writing papers, benchmarks, or teaching material.

---

## 16. Testing, Verification, And Quality Infrastructure

### 16.1 Test inventory in current tree

1. Total files under `tests/`: 110
2. Python test files: 53
3. Nyx test files: 13

### 16.2 Scripted quality gates available

1. `scripts/test_v0.sh` ... `scripts/test_v4.sh`
2. `scripts/test_full_suite.sh`
3. `scripts/test_compatibility.sh`
4. `scripts/test_production.sh`
5. `scripts/test_runtime_hardening.sh`
6. `scripts/test_sanitizers.sh`
7. `scripts/test_vm_consistency.sh`
8. `scripts/test_vm_program_consistency.sh`
9. `scripts/test_fuzz_vm.sh`
10. `scripts/test_soak_runtime.sh`

### 16.3 Tooling checks

1. Parse/lint: `./scripts/nylint.sh`
2. Formatting: `./scripts/nyfmt.sh --check`
3. Package health: `./scripts/nypm.sh doctor`

---

## 17. Reproducible Commands Used For Runtime Validation

These command patterns were used to validate behavior during document preparation:

1. `./nyx --version`
2. `./nyx main.ny`
3. `./nyx --vm main.ny`
4. `./nyx --vm-strict examples/comprehensive.ny`
5. `./nyx --parse-only <file.ny>`
6. `./nyx --trace main.ny`
7. Feature probes using temporary `.ny` scripts for:
- comprehensions
- dual-for iteration
- switch/case
- try/catch
- class/module/typealias
- built-ins and guard flags

---

## 18. Practical Guidance For Publishing Nyx Research

### 18.1 Recommended citation context

When publishing benchmarks or language analysis, specify:

1. Runtime version (`nyx --version`)
2. Backend used (native runtime vs `src/` parser/interpreter vs Python bridge)
3. Exact syntax subset exercised
4. CLI flags (`--vm`, `--vm-strict`, guards)

### 18.2 Recommended reproducibility bundle

Include in supplementary material:

1. All `.ny` benchmark/program files
2. Command lines used
3. Output logs
4. Target platform info (OS, compiler toolchain)
5. Commit hash

### 18.3 Accuracy warning

Do not assume all features in `language/grammar.ebnf` or large spec docs are uniformly active in every backend. Use the compatibility matrix in this document as the starting point, then verify against your exact runtime build.

---

## 19. Appendix A: Minimal Native-Runtime Feature Script

```nyx
print("Nyx feature smoke test");

let arr = [1, 2, 3, 4];
let odds = [x for x in arr if x % 2 == 1];
print(odds[0]);

module M {
    fn add(a, b) { return a + b; }
}
print(M.add(2, 3));

class Point {
    fn init(self, x, y) {
        object_set(self, "x", x);
        object_set(self, "y", y);
    }
    fn sum(self) {
        return object_get(self, "x") + object_get(self, "y");
    }
}
print(new(Point, 3, 4).sum());

try {
    throw "ok";
} catch (e) {
    print(e);
}

switch (2) {
    case 1: { print("one"); }
    case 2: { print("two"); }
    default: { print("other"); }
}

print(lang_version());
```

---

## 20. Appendix B: Key File Map

1. Native runtime entry: `nyx` (binary), sources in `native/nyx.c`
2. Python runtime bridge: `nyx_runtime.py`
3. Lexer/parser/interpreter stack: `src/lexer.py`, `src/parser.py`, `src/interpreter.py`
4. Formal grammar: `language/grammar.ebnf`
5. Core language spec: `docs/LANGUAGE_SPEC.md`
6. Extended spec: `docs/NYX_LANGUAGE_SPECIFICATION_V2.md`
7. Runtime/VM notes: `docs/VM_SPEC.md`
8. Version milestones: `docs/V0.md` to `docs/V4.md`
9. Standard library: `stdlib/`
10. Engine ecosystem manifests: `engines/*/ny.pkg`

---

**End of document**
