# Nyx Virtual Machine & Runtime Specification

**Version:** 1.0  
**Status:** Formal Specification  
**Last Updated:** 2026-02-16

---

## Table of Contents

1. [Overview](#overview)
2. [Bytecode Format](#bytecode-format)
3. [Instruction Set](#instruction-set)
4. [Memory Layout](#memory-layout)
5. [Runtime Model](#runtime-model)
6. [Ownership & Memory Management](#ownership--memory-management)
7. [Scheduler Model](#scheduler-model)
8. [FFI ABI Contract](#ffi-abi-contract)
9. [Execution Model](#execution-model)

---

## 1. Overview

The Nyx Virtual Machine (VM) is a stack-based bytecode interpreter with support for:
- Statically-typed execution
- Ownership-based memory management (no GC)
- Async/await primitives
- Foreign Function Interface (FFI)

### VM Modes

| Mode | Description | Flag |
|------|-------------|------|
| Interpreter | Direct AST execution | Default |
| Bytecode | Compiled bytecode execution | `--vm` |
| Strict | Bytecode only, no fallback | `--vm-strict` |

---

## 2. Bytecode Format

### File Structure

```
┌─────────────────────────────────────────────────────────────┐
│ Header (32 bytes)                                            │
├─────────────────────────────────────────────────────────────┤
│ Magic Number          4 bytes   0x4E 0x59 0x58 0x00 ("NYX\0")│
│ Version               2 bytes   0x0004 (v4)                │
│ Flags                 2 bytes   Bit 0: Debug, Bit 1: Strict│
│ Source Hash           8 bytes   SHA-256 of source           │
│ Code Size            4 bytes   Length of code section       │
│ Constants Count      4 bytes   Number of constants          │
│ Functions Count      4 bytes   Number of functions          │
├─────────────────────────────────────────────────────────────┤
│ Constants Pool       Variable                               │
├─────────────────────────────────────────────────────────────┤
│ Function Table       Variable                               │
├─────────────────────────────────────────────────────────────┤
│ Code Section         Variable                               │
└─────────────────────────────────────────────────────────────┘
```

### Version History

| Version | Bytecode Magic | Description |
|---------|---------------|-------------|
| 0x0001 | `NYX\x01` | Initial format |
| 0x0002 | `NYX\x02` | Added closure support |
| 0x0003 | `NYX\x03` | Added async/await |
| 0x0004 | `NYX\x04` | Current version |

---

## 3. Instruction Set

### Instruction Encoding

Each instruction is 1-4 bytes:
- Opcode: 1 byte
- Operands: 0-12 bytes (variable length)

### Opcode Table

#### 3.1 Stack Operations

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0x00 | `NOP` | - | No operation |
| 0x01 | `POP` | - | Pop top of stack |
| 0x02 | `DUP` | - | Duplicate top of stack |
| 0x03 | `SWAP` | - | Swap top two stack items |
| 0x04 | `ROT` | - | Rotate top three items |
| 0x05 | `OVER` | - | Copy second item to top |
| 0x06 | `PICK` | n:1 | Copy nth item to top |

#### 3.2 Constant Loading

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0x10 | `NULL` | - | Push null |
| 0x11 | `TRUE` | - | Push true |
| 0x12 | `FALSE` | - | Push false |
| 0x13 | `ICONST` | n:1 | Push small integer (-128 to 127) |
| 0x14 | `ICONST_I16` | n:2 | Push 16-bit integer |
| 0x15 | `ICONST_I32` | n:4 | Push 32-bit integer |
| 0x16 | `FCONST` | n:4 | Push 32-bit float |
| 0x17 | `DCONST` | n:8 | Push 64-bit float |
| 0x18 | `SCONST` | len:1, str:len | Push string constant |
| 0x19 | `CONST` | idx:2 | Push constant by index |

#### 3.3 Local Variables

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0x20 | `LOAD` | idx:1 | Load local variable (0-255) |
| 0x21 | `LOAD_I16` | idx:2 | Load local (0-65535) |
| 0x22 | `LOADN` | - | Load local 0 (fast) |
| 0x23 | `STORE` | idx:1 | Store local variable |
| 0x24 | `STORE_I16` | idx:2 | Store local (0-65535) |
| 0x25 | `STOREN` | - | Store local 0 (fast) |

#### 3.4 Global Variables

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0x30 | `GLOAD` | idx:2 | Load global by index |
| 0x31 | `GSTORE` | idx:2 | Store global by index |
| 0x32 | `GDEF` | idx:2, val | Define global |

#### 3.5 Control Flow

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0x40 | `JUMP` | offset:2 | Unconditional jump |
| 0x41 | `JUMPIF` | offset:2 | Jump if false |
| 0x42 | `JUMPIF_NOT` | offset:2 | Jump if true |
| 0x43 | `CALL` | idx:2, argc:1 | Call function |
| 0x44 | `CALL_I16` | idx:2, argc:2 | Call function (many args) |
| 0x45 | `RET` | - | Return from function |
| 0x46 | `RET_VAL` | - | Return with value |
| 0x47 | `CALL_METHOD` | idx:2, argc:1 | Call method |
| 0x48 | `SUPER` | - | Call parent constructor |

#### 3.6 Arithmetic

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0x50 | `ADD` | - | Add (a + b) |
| 0x51 | `SUB` | - | Subtract (a - b) |
| 0x52 | `MUL` | - | Multiply (a * b) |
| 0x53 | `DIV` | - | Divide (a / b) |
| 0x54 | `MOD` | - | Modulo (a % b) |
| 0x55 | `NEG` | - | Negate |
| 0x56 | `POW` | - | Power (a ** b) |
| 0x57 | `DIV_I` | - | Integer division |

#### 3.7 Comparison

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0x60 | `EQ` | - | Equal (a == b) |
| 0x61 | `NE` | - | Not equal (a != b) |
| 0x62 | `LT` | - | Less than (a < b) |
| 0x63 | `LE` | - | Less or equal (a <= b) |
| 0x64 | `GT` | - | Greater than (a > b) |
| 0x65 | `GE` | - | Greater or equal (a >= b) |

#### 3.8 Logical

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0x70 | `AND` | - | Logical AND |
| 0x71 | `OR` | - | Logical OR |
| 0x72 | `NOT` | - | Logical NOT |
| 0x73 | `COALESCE` | - | Null coalescing (a ?? b) |

#### 3.9 Bitwise

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0x80 | `BAND` | - | Bitwise AND |
| 0x81 | `BOR` | - | Bitwise OR |
| 0x82 | `BXOR` | - | Bitwise XOR |
| 0x83 | `BNOT` | - | Bitwise NOT |
| 0x84 | `SHL` | - | Left shift |
| 0x85 | `SHR` | - | Right shift |

#### 3.10 Object Operations

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0x90 | `NEWOBJ` | nfields:1 | Create new object |
| 0x91 | `NEWOBJ_I16` | nfields:2 | Create object (many fields) |
| 0x92 | `GET` | key | Get property |
| 0x93 | `SET` | key | Set property |
| 0x94 | `GETI` | - | Get by index (obj[key]) |
| 0x95 | `SETI` | - | Set by index (obj[key] = val) |
| 0x96 | `DELETE` | key | Delete property |
| 0x97 | `HAS` | key | Has property check |
| 0x98 | `NEWCLASS` | idx:2 | Create class |

#### 3.11 Array Operations

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0xA0 | `NEWARR` | - | Create new array |
| 0xA1 | `NEWARR_I` | size:2 | Create array with size |
| 0xA2 | `GETIDX` | - | Get array element |
| 0xA3 | `SETIDX` | - | Set array element |
| 0xA4 | `LEN` | - | Get length |
| 0xA5 | `PUSH` | - | Push to array |
| 0xA6 | `POP` | - | Pop from array |

#### 3.12 Closure Operations

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0xB0 | `CLOSURE` | fn_idx:2, nupvals:1 | Create closure |
| 0xB1 | `CLOSUREI` | fn_idx:2, nupvals:1 | Create closure (index-based) |
| 0xB2 | `UPVAL_GET` | idx:1 | Get upvalue |
| 0xB3 | `UPVAL_SET` | idx:1 | Set upvalue |
| 0xB4 | `CLOSURE_CALL` | nargs:1 | Call closure |

#### 3.13 Async Operations

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0xC0 | `ASYNC` | fn_idx:2 | Create async function |
| 0xC1 | `AWAIT` | - | Await promise |
| 0xC2 | `SPAWN` | fn_idx:2 | Spawn task |
| 0xC3 | `SPAWN_RET` | - | Spawn and return task |
| 0xC4 | `YIELD` | - | Yield execution |
| 0xC5 | `AWAIT_ALL` | n:1 | Await multiple |

#### 3.14 Error Handling

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0xD0 | `THROW` | - | Throw exception |
| 0xD1 | `THROW_I` | idx:2 | Throw by index |
| 0xD2 | `TRY` | catch:2, finally:2 | Setup try-catch |
| 0xD3 | `TRY_END` | - | End try block |
| 0xD4 | `RETHROW` | - | Rethrow exception |

#### 3.15 Type Operations

| Opcode | Name | Operands | Description |
|--------|------|----------|-------------|
| 0xE0 | `IS_NULL` | - | Check null |
| 0xE1 | `IS_TYPE` | type:1 | Check type |
| 0xE2 | `TYPEOF` | - | Get type |
| 0xE3 | `CAST` | type:1 | Type cast |
| 0xE4 | `CONV` | type:1 | Type conversion |

---

## 4. Memory Layout

### 4.1 Object Structure

```
┌────────────────────────────────────────────────────────────┐
│ Object Header (16 bytes on 64-bit)                         │
├────────────────────────────────────────────────────────────┤
│ Type Tag      4 bytes   Object type identifier             │
│ Size          4 bytes   Total size including header        │
│ Ref Count     8 bytes   Reference count (or GC info)       │
├────────────────────────────────────────────────────────────┤
│ Payload       Variable                                     │
└────────────────────────────────────────────────────────────┘
```

### 4.2 Type Tags

| Tag | Type | Description |
|-----|------|-------------|
| 0x00 | `NIL` | Null/None |
| 0x01 | `BOOL` | Boolean |
| 0x02 | `INT` | Integer |
| 0x03 | `FLOAT` | Floating point |
| 0x04 | `STRING` | String |
| 0x05 | `ARRAY` | Array |
| 0x06 | `OBJECT` | Object/Hash |
| 0x07 | `FUNCTION` | Function |
| 0x08 | `CLOSURE` | Closure |
| 0x09 | `CLASS` | Class |
| 0x0A | `INSTANCE` | Class instance |
| 0x0B | `MODULE` | Module |
| 0x0C | `FUTURE` | Async future |
| 0x0D | `COROUTINE` | Coroutine/task |

### 4.3 Memory Regions

```
┌─────────────────────────────────────────────────────────────┐
│ Stack (grows down)                                          │
│ - Local variables                                          │
│ - Function call frames                                     │
│ - Return addresses                                         │
├─────────────────────────────────────────────────────────────┤
│ Protected Guard Page (1 page)                              │
├─────────────────────────────────────────────────────────────┤
│ Heap (grows up)                                            │
│ - Allocated objects                                        │
│ - Arrays                                                   │
│ - Strings                                                  │
│ - Closures                                                 │
├─────────────────────────────────────────────────────────────┤
│ Static Data                                                │
│ - Global constants                                         │
│ - Code                                                     │
│ - Class definitions                                        │
└─────────────────────────────────────────────────────────────┘
```

### 4.4 String Representation

```
┌────────────────────────────────────────────────────────────┐
│ String Object (24 bytes header + content)                  │
├────────────────────────────────────────────────────────────┤
│ Type: STRING        4 bytes  0x04                          │
│ Size: 4 + len      4 bytes  Header + content size         │
│ Ref Count          8 bytes  Reference count                 │
├────────────────────────────────────────────────────────────┤
│ Hash              4 bytes  FNV-1a hash                     │
│ Length            4 bytes  String length                   │
├────────────────────────────────────────────────────────────┤
│ Content           len bytes UTF-8 encoded string           │
└────────────────────────────────────────────────────────────┘
```

### 4.5 Array Representation

```
┌────────────────────────────────────────────────────────────┐
│ Array Object                                                │
├────────────────────────────────────────────────────────────┤
│ Type: ARRAY       4 bytes  0x05                           │
│ Size              4 bytes  Total size                      │
│ Ref Count         8 bytes  Reference count                 │
├────────────────────────────────────────────────────────────┤
│ Capacity         4 bytes  Allocated elements                │
│ Length           4 bytes  Number of elements                │
├────────────────────────────────────────────────────────────┤
│ Elements         Variable  Array of nyx_value              │
└────────────────────────────────────────────────────────────┘
```

---

## 5. Runtime Model

### 5.1 Execution Flow

```
┌─────────────────────────────────────────────────────────────┐
│ main()                                                      │
│   └─> NYX_Initialize()                                      │
│         - Setup runtime                                      │
│         - Load standard library                             │
│         - Initialize memory allocator                       │
│   └─> NYX_Parse()                                           │
│         - Lexical analysis (lexer)                          │
│         - Syntax analysis (parser)                          │
│         - Build AST                                         │
│   └─> NYX_Compile() [if --vm]                               │
│         - Generate bytecode                                  │
│         - Optimize                                          │
│   └─> NYX_Execute()                                         │
│         - Interpret or run bytecode                        │
│   └─> NYX_Cleanup()                                         │
│         - Free memory                                       │
│         - Cleanup resources                                │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Call Stack

```
┌────────────────────────────────────────────────────────────┐
│ Frame N                                                     │
│ ├─ Return Address                                          │
│ ├─ Previous Frame Pointer                                  │
│ ├─ Local 0                                                 │
│ ├─ Local 1                                                 │
│ ├─ ...                                                     │
│ └─ Local N                                                 │
├────────────────────────────────────────────────────────────┤
│ Frame N-1                                                  │
│ └─ ...                                                     │
└────────────────────────────────────────────────────────────┘
```

### 5.3 Value Representation

```c
typedef union {
    int64_t         i;      // Integer
    double          d;      // Float
    void*           p;      // Pointer (string, array, object)
    struct {                // Tagged representation
        uint64_t    value;
        uint8_t     type;
        uint8_t     flags;
    };
} nyx_value;
```

---

## 6. Ownership & Memory Management

### 6.1 Memory Safety Model

Nyx uses **ownership-based memory management** without a garbage collector:

| Property | Implementation |
|----------|---------------|
| Single Owner | Each value has one owner |
| Move Semantics | Ownership transfers on assignment |
| Borrow Checking | Compile-time validation |
| RAII | Destructors called at scope end |
| No GC | Zero GC pauses |

### 6.2 Safety Checks

When `NYX_SAFETY_ENABLED`:

```c
// Null check
#define NYX_NULL_CHECK(v) \
    if ((v) == NULL) NYX_PANIC("null dereference")

// Bounds check
#define NYX_BOUNDS_CHECK(arr, idx) \
    if ((idx) < 0 || (idx) >= (arr)->len) \
        NYX_PANIC("index out of bounds")

// Overflow check
#define NYX_OVERFLOW_CHECK(op) \
    if (NYX_OVERFLOW_DETECTED) NYX_PANIC("overflow")
```

### 6.3 Allocation Limits

Runtime flags for resource limits:

| Flag | Description | Example |
|------|-------------|---------|
| `--max-alloc N` | Maximum bytes allocated | 1,000,000 |
| `--max-steps N` | Maximum execution steps | 100,000 |
| `--max-call-depth N` | Maximum call depth | 2048 |

---

## 7. Scheduler Model

### 7.1 Task States

```
                    ┌──────────────┐
                    │   CREATED    │
                    └──────┬───────┘
                           │ spawn()
                           ▼
                    ┌──────────────┐
         ┌──────────│   READY      │──────────┐
         │          └──────┬───────┘          │
         │                 │                   │
    yield()          schedule()           complete()
         │                 │                   │
         ▼                 ▼                   ▼
   ┌──────────┐     ┌──────────┐      ┌──────────┐
   │ RUNNING  │────>│ RUNNING  │      │COMPLETED │
   └──────────┘     └──────────┘      └──────────┘
                           │
                           │ await()
                           ▼
                    ┌──────────────┐
                    │   BLOCKED    │
                    └──────────────┘
```

### 7.2 Scheduler Implementation

```c
typedef struct {
    TaskQueue   ready_queue;      // FIFO of ready tasks
    TaskQueue   waiting_queue;    // Tasks waiting on I/O
    uint32_t    num_workers;     // Number of worker threads
    bool        running;         // Scheduler running flag
} NyxScheduler;
```

### 7.3 Work Stealing

The scheduler implements work stealing for load balancing:
1. Each worker has a local task queue
2. When empty, steal from other workers
3. Minimizes lock contention

---

## 8. FFI ABI Contract

### 8.1 Type Mappings

| Nyx Type | C Type | Size |
|----------|--------|------|
| `int` | `int64_t` | 8 bytes |
| `float` | `float` | 4 bytes |
| `double` | `double` | 8 bytes |
| `bool` | `int` | 4 bytes |
| `string` | `const char*` | ptr |
| `array` | `nyx_array_t*` | ptr |
| `object` | `nyx_object_t*` | ptr |

### 8.2 Calling Conventions

**cdecl (default on x86-64 System V):**
- Arguments: RDI, RSI, RDX, RCX, R8, R9, then stack
- Return: RAX (integer), XMM0 (float)

**win64 (Windows x64):**
- Arguments: RCX, RDX, R8, R9, then stack
- Return: RAX (integer), XMM0 (float)

### 8.3 FFI Safety Rules

1. **Validate all pointers** - Never trust foreign pointers
2. **Check bounds** - Array access must be bounds-checked
3. **Handle errors** - Check return values
4. **Ownership** - Clear ownership transfer at FFI boundary
5. **Thread safety** - Don't share mutable state across FFI

### 8.4 FFI Example

```nyx
import "c";

// Call C function
let puts = c.function("int", "puts", ["const char*"]);
puts("Hello from C!");

// Create C struct
let malloc = c.function("void*", "malloc", ["size_t"]);
let ptr = malloc(1024);

// Clean up
let free = c.function("void", "free", ["void*"]);
free(ptr);
```

---

## 9. Execution Model

### 9.1 Interpreter Loop

```c
// Main execution loop
while (ctx->ip < code_end) {
    switch (*ctx->ip++) {
        case OP_ADD:   // ...
        case OP_CALL:  // ...
        case OP_JUMP:  // ...
        // ... handle all opcodes
    }
}
```

### 9.2 Bytecode Execution

When `--vm` flag is used:
1. Source is compiled to bytecode
2. Bytecode is cached (`.nyc` file)
3. VM executes bytecode directly
4. Faster for repeated executions

### 9.3 Strict Mode

`--vm-strict` flag:
- Only bytecode execution allowed
- No fallback to interpreter
- Ensures deterministic behavior

---

## Appendix A: Opcode Quick Reference

| Range | Category |
|-------|----------|
| 0x00-0x0F | Stack & Misc |
| 0x10-0x1F | Constants |
| 0x20-0x2F | Local Variables |
| 0x30-0x3F | Global Variables |
| 0x40-0x4F | Control Flow |
| 0x50-0x5F | Arithmetic |
| 0x60-0x6F | Comparison |
| 0x70-0x7F | Logical |
| 0x80-0x8F | Bitwise |
| 0x90-0x9F | Objects |
| 0xA0-0xAF | Arrays |
| 0xB0-0xBF | Closures |
| 0xC0-0xCF | Async |
| 0xD0-0xDF | Error Handling |
| 0xE0-0xEF | Type Operations |

---

*Last Updated: 2026-02-16*
*Version: 1.0*
