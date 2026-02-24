<p align="center">
  <img src="assets/nyx-logo.png" alt="Nyx Logo" width="200"/>
</p>

<h1 align="center">Nyx Programming Language</h1>

<p align="center">
  <strong>One Language. Every Domain. Zero Compromise.</strong>
</p>

<p align="center">
  <a href="#quickstart">Quickstart</a> &bull;
  <a href="#language-overview">Language</a> &bull;
  <a href="#engine-ecosystem">Engines</a> &bull;
  <a href="#compiler--runtime">Compiler</a> &bull;
  <a href="#standard-library">Stdlib</a> &bull;
  <a href="#examples">Examples</a> &bull;
  <a href="#tooling">Tooling</a> &bull;
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <code>v5.5.0</code> &nbsp;|&nbsp; Native Compiler v3.3.3 &nbsp;|&nbsp; &copy; 2026 Surya Sekhar Roy
</p>

---

## What is Nyx?

**Nyx** is a systems-to-application programming language that unifies the capabilities of C, Rust, Python, JavaScript, SQL, and dozens of domain-specific languages into a single, coherent syntax. It compiles to native binaries via a C99 backend, runs interpreted via a Python runtime, and serves web applications through a built-in HTTP server &mdash; all from `.ny` source files.

Nyx replaces entire technology stacks:

| What You'd Use | Nyx Equivalent |
|---|---|
| C / C++ / Rust (systems) | Native compiler, ownership model, inline ASM |
| Python (scripting, ML) | Interpreted mode, `nyml`/`nytensor`/`nygrad` engines |
| JavaScript / TypeScript (web) | `nyweb` framework, `nyui` virtual DOM, SSR |
| SQL (databases) | `nydb` multi-model engine with NySQL |
| CUDA / OpenCL (GPU) | `nygpu` multi-backend compute |
| Docker / Kubernetes (infra) | `nykube`, `nydeploy`, `nyserverless` engines |
| TensorFlow / PyTorch (ML) | `nyml`, `nynet`, `nygrad`, `nyopt`, `nyloss` |
| Unity / Unreal (games) | `nygame`, `nyrender`, `nyphysics`, `nyaudio`, `nyanim` |
| ROS (robotics) | `nyrobot` kinematics + path planning |
| Bloomberg Terminal (finance) | `nyhft`, `nytrade`, `nymarket`, `nyrisk`, `nybacktest` |

---

## Quickstart

### Install

```bash
# Clone the repository
git clone https://github.com/user/nyx-lang.git
cd nyx-lang

# Option 1: Run interpreted (requires Python 3.8+)
python run.py hello.ny

# Option 2: Build native compiler (requires GCC)
make
./build/nyx hello.ny

# Option 3: Windows batch
nyx.bat hello.ny

# Option 4: Unix shell
./nyx.sh hello.ny
```

### Hello World

```nyx
# hello.ny
print("Hello, Nyx!")
```

### A Real Program

```nyx
# Variables (let bindings, optional semicolons)
let name = "Nyx"
let version = 5.5
let features = ["compiled", "interpreted", "web-native"]

# Functions
fn greet(who: String) -> String {
    return "Hello, " + who + "!"
}

# Classes
class Language {
    let name: String
    let compiled: Bool

    fn new(name: String) -> Self {
        return Self { name: name, compiled: true }
    }

    fn describe(self) -> String {
        return self.name + " is a compiled language"
    }
}

# Pattern matching
let result = match version {
    5.5 => "latest",
    _ => "older"
}

# Async
async fn fetch_data(url: String) -> String {
    let response = await http.get(url)
    return response.body
}

# Pipeline operator
let processed = [1, 2, 3, 4, 5]
    |> filter(|x| x > 2)
    |> map(|x| x * x)
    |> reduce(|a, b| a + b)

print(greet(name))
```

---

## Language Overview

### Syntax

Nyx supports **dual syntax** &mdash; both C-style braces and Python-style indentation:

```nyx
# C-style (braces)
fn factorial(n: Int) -> Int {
    if n <= 1 {
        return 1
    }
    return n * factorial(n - 1)
}

# Python-style (indentation)
fn factorial(n: Int) -> Int:
    if n <= 1:
        return 1
    return n * factorial(n - 1)
```

**Semicolons are optional.** All of these are valid:

```nyx
let x = 5;
let y = 10
let z = x + y;
```

### Dual Import System

Both `import` and `use` keywords work identically:

```nyx
import nymath          # Module import
use nymath             # Same thing

import "path/module"   # Quoted path
use path.module        # Dot notation

from nymath import sin, cos    # Selective import
use nymath { sin, cos }        # Destructured import
```

### Type System

Nyx has a comprehensive, gradually-typed system:

#### Primitives
`int`, `i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`, `f32`, `f64`, `bool`, `char`, `str`, `null`, `void`, `never`

#### Compound Types
```nyx
let arr: [Int] = [1, 2, 3]                    # Arrays
let slice: [Int] = arr[1..3]                   # Slices
let obj: {name: String, age: Int} = {}         # Objects
let tuple: (Int, String) = (42, "hello")       # Tuples
let func: fn(Int) -> Bool = |x| x > 0         # Functions
let ref: &Int = &some_value                    # References
let mut_ref: &mut Int = &mut some_value        # Mutable references
```

#### Generics
```nyx
class Stack<T> {
    let items: [T]

    fn push(self, item: T) { self.items.push(item) }
    fn pop(self) -> T? { return self.items.pop() }
}

fn identity<T>(x: T) -> T { return x }
```

#### Enums with Data
```nyx
enum Result<T, E> {
    Ok(T),
    Err(E)
}

enum Shape {
    Circle { radius: Float },
    Rectangle { width: Float, height: Float }
}
```

#### Traits / Interfaces
```nyx
trait Drawable {
    fn draw(self)
    fn area(self) -> Float
}

class Circle : Drawable {
    let radius: Float

    fn draw(self) { /* ... */ }
    fn area(self) -> Float { return 3.14159 * self.radius * self.radius }
}
```

#### Union Types & Null Safety
```nyx
let value: Int | String = 42
let optional: String? = null    # Option<String>

fn safe_divide(a: Float, b: Float) -> Result<Float, String> {
    if b == 0.0 { return Err("division by zero") }
    return Ok(a / b)
}
```

### Ownership & Memory Safety

Nyx uses a Rust-inspired ownership model:

```nyx
# Move semantics
let a = vec![1, 2, 3]
let b = a              # `a` is moved, no longer valid

# Borrowing
fn sum(data: &[Int]) -> Int {
    let total = 0
    for x in data { total = total + x }
    return total
}

# Mutable borrowing
fn append(data: &mut Vec<Int>, value: Int) {
    data.push(value)
}

# Lifetimes
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { return x }
    return y
}

# RAII - automatic cleanup
{
    let file = File::open("data.txt")   # Resource acquired
    file.write("hello")
}   # `file` dropped here, resource released
```

### Concurrency

```nyx
# Async/Await
async fn fetch_all(urls: [String]) -> [String] {
    let results = []
    for url in urls {
        results.push(await http.get(url))
    }
    return results
}

# Green Threads (spawn)
let handle = spawn {
    expensive_computation()
}
let result = handle.join()

# Channels
let (tx, rx) = channel<Int>()
spawn { tx.send(42) }
let value = rx.recv()

# Mutex
let counter = Mutex::new(0)
spawn {
    let guard = counter.lock()
    *guard = *guard + 1
}

# Select (multiplexing)
select {
    msg <- channel1 => print("Got: " + msg),
    timer.tick() => print("Tick"),
    default => print("Nothing ready")
}
```

### Control Flow

```nyx
# If/Else
if condition {
    action()
} else if other {
    other_action()
} else {
    fallback()
}

# Switch/Match
switch value {
    case 1: print("one")
    case 2: print("two")
    default: print("other")
}

# For loops
for i in 0..10 { print(i) }
for item in array { print(item) }
for key, value in object { print(key, value) }

# While loops
while condition { step() }

# Try/Catch
try {
    risky_operation()
} catch e {
    print("Error: " + e.message)
}

# List comprehension
let squares = [x * x for x in 1..10 if x % 2 == 0]

# Pipeline operator
let result = data |> filter(valid) |> map(transform) |> reduce(combine)
```

---

## Compiler & Runtime

Nyx has **three execution modes**:

### 1. Native C Compiler (v3.3.3)

Compiles `.ny` &rarr; C &rarr; native binary via GCC.

```bash
make                        # Build compiler
./build/nyx program.ny      # Compile & run
```

**Compiler source**: `native/nyx.c` + `compiler/v3_compiler_template.c`

The native compiler is a complete implementation in C99 (~1500+ lines) featuring:
- **Lexer**: 55 token types including all keywords (`let`, `fn`, `class`, `module`, `if`, `else`, `switch`, `case`, `while`, `for`, `in`, `try`, `catch`, `throw`, `import`, `use`, `return`, `break`, `continue`, `async`, `await`, `typealias`, `true`, `false`, `null`)
- **Parser**: Recursive descent with full expression/statement AST (`Expr`, `Stmt`, `Block` nodes)
- **Code Generator**: Emits C code with built-in module support
- **Built-in Modules**: `nymath` (abs, min, max, clamp, pow, sum), `nyarrays` (first, last, sum, enumerate), `nyobjects` (merge, get_or), `nyjson` (parse, stringify), `nyhttp` (get, text, ok)

Build flags: `gcc -O2 -std=c99 -o build/nyx native/nyx.c`

### 2. Python Interpreter

Runs `.ny` files directly via a full interpreter pipeline.

```bash
python run.py program.ny
```

**Architecture** (`src/`):

| File | Purpose |
|---|---|
| `src/lexer.py` | Tokenizer with Unicode support, multiple comment styles, format/raw/byte strings, error recovery |
| `src/parser.py` | Pratt parser with 11 precedence levels, class/import/async/yield/try/with support |
| `src/interpreter.py` | Tree-walking evaluator with `Environment` scoping, class instances, async via `asyncio` |
| `src/ast_nodes.py` | Full AST node definitions (30+ node types) |
| `src/token_types.py` | Token type enumeration and registry |
| `src/compiler.py` | Compilation pipeline |
| `src/borrow_checker.py` | Ownership/borrow analysis |
| `src/ownership.py` | Ownership semantics |
| `src/debugger.py` | Debug support |
| `src/async_runtime.py` | Async execution runtime |
| `src/polyglot.py` | Multi-language interop |

**Key AST Nodes**: `Program`, `LetStatement`, `ReturnStatement`, `ExpressionStatement`, `BlockStatement`, `IfExpression`, `WhileStatement`, `ForStatement`, `ForInStatement`, `FunctionLiteral`, `CallExpression`, `ClassStatement`, `NewExpression`, `ImportStatement`, `UseStatement`, `FromStatement`, `TryStatement`, `AsyncStatement`, `AwaitExpression`, `YieldExpression`, `AssignExpression`, `InfixExpression`, `PrefixExpression`, `IndexExpression`, `ArrayLiteral`, `HashLiteral`, `StringLiteral`, `IntegerLiteral`, `FloatLiteral`, `BooleanLiteral`, `NullLiteral`, `BreakStatement`, `ContinueStatement`, `SelfExpression`, `SuperExpression`

**Precedence Levels**: LOWEST(1) &rarr; ASSIGN(2) &rarr; YIELD(3) &rarr; LOGICAL(4) &rarr; EQUALS(5) &rarr; LESSGREATER(6) &rarr; SUM(7) &rarr; PRODUCT(8) &rarr; PREFIX(9) &rarr; CALL(10) &rarr; INDEX(11)

### 3. Web Runtime

Serves `.ny` as web applications with a built-in HTTP server.

```bash
python nyx_runtime.py
```

**Runtime Classes** (`nyx_runtime.py`):

| Class | Methods |
|---|---|
| `PersistentStore` | `get()`, `set()`, `has()`, `transaction()` |
| `Request` | HTTP request object |
| `Response` | HTTP response object |
| `HttpRoute` | Route definition |
| `Application` | `worker_model()`, `worker_pool()`, `worker_stats()`, `dispatch()` |
| `RuntimeConfig` | Server configuration |
| `NyxRuntimeServer` | `metric()`, `set_metric()`, `bump_visit()`, `bump_run()`, `next_signup()`, `save_signup()`, `preview_html()` |
| `NyxHandler` | `do_GET()`, `do_POST()` |

**API Endpoints**: `/api/health`, `/api/overview`, `/api/metrics`, `/api/community/subscribe`, `/api/playground/run`

### Bootstrap Compiler

The `compiler/` directory contains the self-hosting bootstrap:

- `compiler/bootstrap.ny` &mdash; v2 bootstrap compiler (single-expression .ny &rarr; C)
- `compiler/v3_seed.ny` &mdash; v3 self-hosting seed (reads template, outputs C compiler)
- `compiler/v3_compiler_template.c` &mdash; Full C compiler template

---

## Engine Ecosystem

Nyx ships with **80+ specialized engines** organized by domain. Each engine is a `.ny` module under `engines/`.

### Game Development

| Engine | Purpose | Key APIs |
|---|---|---|
| **nygame** | Game engine framework | `Engine`, `Window`, `Renderer`, `GraphicsAPI` enum (Vulkan/DX12/Metal/OpenGL), `EngineState`, `RenderPipeline` |
| **nyrender** | GPU-driven graphics | `RenderConfig`, `pbr.MaterialGraph`, `pbr.MaterialCompiler`, `pbr.NeuralMaterialCodec`, `raytracing.RtSettings`, `raytracing.AccelerationStructure`, `raytracing.NeuralRadianceCache` |
| **nyphysics** | Deterministic physics | `PhysicsConfig`, `rigid.RigidBody`, `rigid.Constraint`, `rigid.ContinuousCollision`, `rigid.ConstraintSolver`, `softbody.SoftBody`, `softbody.FEMElement`, `vehicle.TireModel`, `vehicle.Suspension` |
| **nyanim** | Animation system | `ik.Skeleton`, `ik.FullBodyIK`, `motion.MotionMatcher`, `motion.MotionDatabase`, `face.FacialRig`, `face.FacialSolver`, `blend.BlendTree`, `locomotion.LocomotionSynthesis` |
| **nyaudio** | 3D spatial audio | `spatial.Listener`, `spatial.Source3D`, `spatial.HRTFProcessor`, `acoustics.OcclusionSystem`, `acoustics.DopplerSystem`, `reverb.ConvolutionReverb`, `music.DynamicScore`, `ambience.AmbienceContext` |
| **nyworld** | Open-world streaming | `partition.PartitionManager`, `streaming.AsyncIO`, `terrain.TerrainEngine`, `city.RoadNode`, `city.DistrictRule` |
| **nyai** | Game AI | `hybrid.BehaviorTree`, `hybrid.GOAPPlanner`, `hybrid.Brain`, `path.HierarchicalAStar`, `crowd.CrowdSystem` |
| **nycore** | Engine core | `memory.ArenaAllocator`, `memory.PoolAllocator`, `memory.MemoryManager`, `scheduler.JobSystem` (work-stealing), `taskgraph.TaskGraph` |

### Machine Learning & AI

| Engine | Purpose | Key APIs |
|---|---|---|
| **nyml** | ML framework | `Tensor`, `Dense`, `Conv2D`, `MaxPool2D`, `Dropout`, `BatchNorm`, `ReLU`, `Sigmoid`, `Tanh`, `Softmax`, `Model` |
| **nytensor** | Tensor computation | `DType` (Float16&ndash;Float64, Int8&ndash;Int64, Bool, Complex128), `Device` (CPU/CUDA/ROCm/Metal), `Shape`, `MemoryPool`, `ArenaAllocator`, `Tensor` (zeros/ones/rand/randn/eye/arange/linspace) |
| **nygrad** | Automatic differentiation | `OpType` (30 ops), `GradNode`, `Tape`, `Variable` (tracked add/sub/mul/div/matmul/relu/sigmoid/exp/log) |
| **nynet** | Neural network layers | `Layer` trait, `Linear`, `Conv2d`, `BatchNorm2d`, `LayerNorm` |
| **nyloss** | Loss functions | `CrossEntropyLoss`, `BinaryCrossEntropyLoss`, `BCEWithLogitsLoss`, `MSELoss`, `MAELoss`, `HuberLoss`, `KLDivLoss` |
| **nyopt** | Optimizers | `SGD` (momentum, Nesterov), `Adam` (AMSGrad), `AdamW` (decoupled weight decay), learning rate schedulers |
| **nydata** | Data pipelines | `DataSchema`, `Sample`, `Batch`, `Transform`, `Normalize`, `Standardize`, `RandomCrop`, `DataFormat` (CSV/JSON/Parquet/Arrow/Image) |
| **nyquant** | Model compression | `QuantMode` (INT8/INT4/FP16/BF16), `QuantizedTensor`, `Quantizer`, calibration methods (MinMax/Histogram/Entropy) |
| **nysci** | Scientific computing | `Tensor` (autograd), linear algebra, FFT, optimization, statistics, neural network primitives |
| **nyrl** | Reinforcement learning | `Env`, `Space` (Discrete/Continuous), `ReplayBuffer`, `PrioritizedReplayBuffer`, PPO/DQN/DDPG/SAC/TD3 |
| **nymind** | Cognitive reasoning | `rules.InferenceEngine` (forward/backward chaining), `logic.Term`, `rules.Fact`, `rules.Rule`, knowledge graphs |

### Web & Server

| Engine | Purpose | Key APIs |
|---|---|---|
| **nyweb** | Web framework | `Application` (route/use/get/post/put/delete/run/dispatch), `Route`, `Middleware`, `Request`, `Response` |
| **nyhttp** | HTTP protocol | `protocol.*` (methods, status codes), `url.Url` (RFC 3986), HTTP/1.1-2-3, TLS 1.3, WebSocket, SSE |
| **nyserver** | Server infrastructure | `async_core.EventLoop`, `async_core.Task`, `worker_pool.Worker`, `worker_pool.WorkerPool`, cluster mode, health checks |
| **nyui** | UI framework (Virtual DOM) | `VNode`, `VNodeType`, element builder DSL (`html`, `head`, `body`), `toHtml()`, event binding, SSR |
| **nyserverless** | FaaS engine | `FunctionConfig`, `FunctionInstance` (cold/warm start), `InvocationContext`, `Trigger` (HTTP/schedule/queue/storage/event), auto-scaling |
| **nydeploy** | Deployment engine | `BlueGreenDeployer`, `CanaryDeployer`, rolling updates, health checks, rollback |

### Data & Infrastructure

| Engine | Purpose | Key APIs |
|---|---|---|
| **nydb** | Multi-model database | `storage.StorageEngine` (B-Tree/LSM), `query.QueryPlanner` (cost-based optimizer), `query.NySQL`, `transaction.TransactionManager` (ACID/MVCC/WAL), `index.VectorIndex` (HNSW), `cluster.Consensus` (Raft) |
| **nykube** | Kubernetes orchestration | `resources.Pod`, `resources.ContainerSpec`, `deployments.Deployment` (rolling update, scale, rollback), `services.ServicePort` |
| **nynetwork** | Networking | `Socket`, `ServerSocket`, `HTTPClient`, `HTTPServer`, `WebSocket`, `WebSocketServer` |
| **nyasync** | Concurrency engine | `Future` trait, `EventLoop`, `AsyncRuntime` (spawn/block_on), `ThreadPool`, `Worker` |
| **nymonitor** | Observability | `MetricsCollector` (counter/gauge/histogram), `LogAggregator`, Prometheus export, distributed tracing |

### Systems & Low-Level

| Engine | Purpose | Key APIs |
|---|---|---|
| **nysystem** | Systems programming | 200+ Linux syscall constants (`SYS_read` through `SYS_newfstatat`), process management, FFI, driver framework |
| **nygpu** | GPU compute | `GPUBackend` (CUDA/Vulkan/Metal/ROCm/OpenCL/CPU), `DeviceManager`, `GPUMemory` |
| **nykernel** | Compute kernels | `CUDAKernel` (JIT compile to PTX), `CPUKernel` (parallel fallback), `KernelGraph` (fusion engine) |
| **nycrypto** | Cryptography | `SHA256`, `SHA512`, `SHA1`, `MD5`, `BLAKE2b`, `BLAKE2s`, `AES`, `DES`, `RC4`, `ChaCha20`, RSA/ECC, post-quantum (Kyber, Dilithium) |

### Finance & Trading

| Engine | Purpose | Key APIs |
|---|---|---|
| **nyhft** | High-frequency trading | `lockfree.SPSCQueue`, `lockfree.MPSCQueue`, `lockfree.RingBuffer`, `lockfree.AtomicCounter`, `network.KernelBypassSocket` (DPDK), `scheduling.CPUPinner` |
| **nytrade** | Trade execution | `orders.Order` (market/limit/stop_limit), `orders.Fill`, `gateway.ExchangeGateway` (FIX protocol), `routing.SmartRouter` (best_price/TWAP/VWAP) |
| **nymarket** | Market data | `types.Tick`, `types.Trade`, `types.Bar`, `orderbook.OrderBook` (microprice, depth, imbalance), `feed.MarketFeed` |
| **nyrisk** | Risk management | `metrics.VaRCalculator` (historical/parametric/Monte Carlo), `metrics.expected_shortfall`, `greeks.BlackScholes` (price/greeks/implied_vol), `stress.StressTester` |
| **nybacktest** | Strategy backtesting | `strategy.Strategy`, `strategy.Signal`, `portfolio.Portfolio` (equity curve, trade log), `events.BacktestEvent` |

### Robotics & Simulation

| Engine | Purpose | Key APIs |
|---|---|---|
| **nyrobot** | Robotics | `kinematics.KinematicChain` (forward/inverse kinematics, Jacobian, dynamics), `path_planning.RRTPlanner`, `path_planning.RRTStarPlanner`, `path_planning.PRMPlanner`, `path_planning.TrajectoryOptimizer` |
| **nysim** | Environment simulation | `world.Vec3`, `world.Entity`, `world.World` (spawn/destroy/find), `physics.RigidBody`, `physics.Collider` |
| **nyswarm** | Multi-agent systems | `core.SwarmAgent` (send/broadcast/receive), `topology.Topology` (ring/star/fully_connected), `topology.LeaderElection`, `shared_state.SharedMemory` |

### Security & Science

| Engine | Purpose | Key APIs |
|---|---|---|
| **nysec** | Cybersecurity | `nyscapy.Packet` (craft/send/sniff), `nyscapy.IP`, `nyscapy.TCP`, `nyscapy.UDP`, `nyscapy.ICMP`, `nyscapy.ARP` |
| **nycloud** | Cloud security | `CloudAPIScanner` (AWS/Azure/GCP), `IAMAnalyzer`, `ContainerScanner`, `KubernetesScanner` |
| **nybio** | Bioinformatics | `DNASequence` (complement/reverse_complement/transcribe/gc_content), `RNASequence.translate()`, `SequenceAligner` (Needleman-Wunsch global, Smith-Waterman local) |
| **nychem** | Computational chemistry | `Molecule`, `Atom`, `Bond`, `Element`, `MDSimulator`, `ForceField` |

### Desktop & Agents

| Engine | Purpose | Key APIs |
|---|---|---|
| **nygui** | Desktop GUI (tkinter-like) | `Application`, `Window`, `Dialog`, `Widget`, `Button`, `Label`, `Entry`, `Canvas`, layout managers, event binding, themes |
| **nyagent** | Autonomous agents | `core.AgentConfig`, `core.Tool`, `core.Action`, `planning.Goal`, `planning.TaskDecomposer`, goal-based planning, reflection loops |

---

## Standard Library

The `stdlib/` directory contains **90+ modules**:

### Core
`math.ny`, `string.ny`, `collections.ny`, `types.ny`, `io.ny`, `json.ny`, `xml.ny`, `regex.ny`, `time.ny`, `log.ny`, `config.ny`, `cli.ny`, `process.ny`, `debug.ny`

### Systems
`ffi.ny`, `simd.ny`, `asm.ny`, `dma.ny`, `interrupts.ny`, `paging.ny`, `hardware.ny`, `allocators.ny`, `atomics.ny`, `smart_ptrs.ny`, `ownership.ny`, `vm.ny`, `vm_bios.ny`, `vm_acpi.ny`, `vm_acpi_advanced.ny`, `vm_devices.ny`, `vm_hotplug.ny`, `vm_iommu.ny`, `vm_migration.ny`, `vm_production.ny`, `vm_tpm.ny`, `vm_metrics.ny`, `vm_logging.ny`, `vm_errors.ny`, `hypervisor.ny`, `debug_hw.ny`, `crypto_hw.ny`, `realtime.ny`

### Networking & Web
`http.ny`, `socket.ny`, `network.ny`, `web.ny`, `redis.ny`, `cache.ny`, `database.ny`, `jwt.ny`

### ML & Data Science
`tensor.ny`, `nn.ny`, `autograd.ny`, `optimize.ny`, `train.ny`, `dataset.ny`, `serving.ny`, `mlops.ny`, `experiment.ny`, `feature_store.ny`, `hub.ny`, `blas.ny`, `fft.ny`, `sparse.ny`, `precision.ny`, `nlp.ny`, `visualize.ny`

### DevOps & Build
`ci.ny`, `compress.ny`, `serialization.ny`, `formatter.ny`, `parser.ny`, `validator.ny`, `lsp.ny`, `metrics.ny`, `monitor.ny`, `distributed.ny`, `state_machine.ny`

### Advanced
`async.ny`, `async_runtime.ny`, `comptime.ny`, `generator.ny`, `science.ny`, `symbolic.ny`, `governance.ny`, `cron.ny`, `game.ny`, `gui.ny`, `bench.ny`, `test.ny`, `algorithm.ny`, `systems.ny`, `systems_extended.ny`, `types_advanced.ny`, `c.ny`

### Native File Generation
Nyx can generate **14+ file formats** with zero external dependencies:

```nyx
use generator

# Text formats
generator.text("output.txt", "Hello World")
generator.markdown("output.md", "# Title\nContent")
generator.csv("output.csv", [["Name", "Age"], ["Alice", "30"]])
generator.rtf("output.rtf", "Rich text content")
generator.svg("output.svg", '<circle cx="50" cy="50" r="40"/>')

# Binary formats
generator.bmp("output.bmp", pixels)
generator.png("output.png", image_data)
generator.ico("output.ico", icon_data)
generator.pdf("output.pdf", "Document content")

# Office formats
generator.docx("output.docx", "Word document")
generator.xlsx("output.xlsx", spreadsheet_data)
generator.pptx("output.pptx", slides)

# Open Document formats
generator.odt("output.odt", "Document content")
generator.ods("output.ods", spreadsheet_data)
generator.odp("output.odp", slides)
```

---

## Examples

The `examples/` directory contains runnable programs across every domain:

### Basic
| File | Description |
|---|---|
| `hello.ny` | Pattern matching, list comprehension, pipeline, async, classes, generics, macros |
| `examples/comprehensive.ny` | Full syntax test &mdash; primitives, strings, arithmetic, arrays, objects, functions, recursion, loops, builtins, try/catch |
| `examples/fibonacci.ny` | Recursive Fibonacci |
| `examples/calculator.ny` | Advanced math: factorial, GCD, LCM, power, sqrt, trig, Matrix class, Complex class, Calculator with history |
| `examples/interactive_calculator.ny` | Tokenizer + shunting-yard parser for arithmetic |

### Web & Full-Stack
| File | Description |
|---|---|
| `examples/http_server_native.ny` | HTTP server with routes, middleware, benchmark page |
| `examples/nyui_example.ny` | NYUI framework &mdash; StudentCard component, reactive Counter, Router, Form validation |
| `examples/fullstack_app/` | Full-stack app &mdash; frontend with `nyui` (JSX-like DSL), backend with `nyweb`+`nydb` (REST API, SQL schema) |
| `examples/ml_webapp.ny` | ML prediction service &mdash; `LinearModel`, `DataStore`, `MLService`, web API |

### Systems & Low-Level
| File | Description |
|---|---|
| `examples/embedded/firmware.ny` | ARM Cortex-M4F bare-metal firmware &mdash; vector table, reset handler, GPIO/USART/Timer registers |
| `examples/os_kernel/kernel_main.ny` | x86_64 OS kernel &mdash; Multiboot2, GDT/IDT, VGA text mode, paging, PIC |

### Applications
| File | Description |
|---|---|
| `examples/gui_calculator.ny` | GUI calculator with `nyagui` &mdash; memory, scientific operations |
| `examples/simple_game.ny` | Game with player movement, combat simulation |
| `examples/space_shooter_game.ny` | Space shooter &mdash; PlayerShip, Bullet, EnemyShip (AI), Particle system |
| `examples/ml_training.ny` | Neural network from scratch &mdash; Tensor, LinearLayer, ReLULayer, NeuralNetwork |
| `examples/school_admission.ny` | Student class, AdmissionStatus enum, Grade class, SchoolDatabase |
| `examples/file_generation_examples.ny` | Generate TXT, MD, CSV, RTF, SVG, PNG, PDF, DOCX, XLSX, PPTX |

---

## Testing

The `tests/` directory contains **180+ test files**:

```bash
# Run tests via interpreter
python run.py tests/test_basic.ny
python run.py tests/test_semicolons.ny
python run.py tests/test_use.ny
python run.py tests/test_stdlib.ny
```

### Test Categories

| Category | Tests | Features Verified |
|---|---|---|
| **Syntax** | `test_basic.ny`, `test_semicolons.ny`, `test_semicolon_optional.ny` | Variables, arrays, loops, functions, optional semicolons |
| **Imports** | `test_use.ny`, `test_stdlib.ny` | `use` keyword, stdlib packages |
| **Engine Smoke** | `test_nyai.ny`, `test_nyanim.ny`, `test_nyaudio.ny`, `test_nycore.ny`, `test_nynet.ny`, `test_nyphysics.ny`, `test_nypm.ny`, `test_nyrender.ny`, `test_nyworld.ny` | Per-engine API validation |
| **UI Framework** | `tests/nyui/test_nyui.ny`, `test_nyui2.ny`, `test_strict.ny`, `test_pure.ny`, `test_web_host.ny` | Virtual DOM, SSR, component lifecycle |
| **Web** | `test_nyweb_simple.ny`, `test_website.ny`, `website.ny` | HTTP routing, response generation |
| **Native** | `test_string_concat_native.ny` | Native string operations |
| **Variables** | `test_vars.ny` | Variable binding and scoping |
| **File Generation** | `test_generator.ny`, `quick_file_gen_test.ny` | File output correctness |

---

## Tooling

### Package Manager &mdash; NYPM

```bash
node nypm.js init              # Create nypm.config
node nypm.js install <pkg>     # Install package
node nypm.js search <query>    # Search registry
node nypm.js list              # List installed
node nypm.js publish           # Publish package
node nypm.js remove <pkg>      # Remove package
node nypm.js update            # Update all
node nypm.js doctor            # Diagnose issues
node nypm.js clean             # Clean cache
node nypm.js info <pkg>        # Package info
node nypm.js versions <pkg>    # List versions
node nypm.js outdated          # Check for updates
```

**Config**: `nypm.config` &nbsp;|&nbsp; **Registry**: `ny.registry`

### NYX Studio

A web-based IDE for visual editing (`tools/nyx_studio/`):

```bash
python tools/nyx_studio/studio_server.py
# Opens at http://localhost:5000
```

**Panels**: Material Graph, Render Pipeline, Physics Constraint, World Rule, AI Intent, Net Replication, Acoustic Zone, Animation Intent, Logic Rule

**Endpoints**: `POST /compile/material`, `POST /compile/pipeline`, `POST /compile/world`, `POST /compile/logic`, `POST /save_asset`

### VS Code Extension

Full language support in `editor/vscode/nyx-language/`:

- Syntax highlighting for `.ny` and `.nx` files
- Snippets (fn, class, for, if, match, import, async)
- File icons
- Bracket matching and auto-closing
- Comment toggling

### Benchmarks

```bash
python run.py benchmarks/bench_fib.ny        # Fibonacci
python run.py benchmarks/bench_loops.ny      # Loop performance
python run.py benchmarks/bench_array.ny      # Array operations
python run.py benchmarks/bench_string.ny     # String operations
python run.py benchmarks/bench_hash.ny       # Hash map operations
python run.py benchmarks/bench_functions.ny  # Function calls
```

---

## Production Configuration

The `configs/production/` directory contains production-grade settings:

| Config | Purpose |
|---|---|
| `gate_thresholds.json` | Performance gates &mdash; render GPU &le;20ms, physics &le;8ms, AI &le;8ms, net tick &le;20ms, audio DSP &le;8ms, API p95 &le;2.5ms |
| `liveops_slo.yaml` | SLOs &mdash; matchmaking p95 &le;1500ms, server tick p95 &le;20ms, reconnect &le;2%, packet loss &le;5%, anti-cheat FP &le;1% |
| `cook_profile.json` | Asset cooking &mdash; deterministic builds, budgets (texture 4GB, mesh 3GB, audio 1GB, animation 2GB) |
| `hardware_matrix.json` | Platform targets &mdash; PC min/rec, console gen current, 95% pass rate, 0 critical failures |
| `anti_cheat_rules.json` | Anti-cheat rule definitions |
| `content_targets.json` | Content delivery targets |
| `team_roster.json` | Team assignments |
| `multi_year_plan.json` | Development roadmap |
| `platform_cert_matrix.json` | Platform certification requirements |
| `aaa_engine_feature_contract.json` | Feature contracts |
| `gta_scale_program.json` | Scale program definition |

---

## Architecture

```
nyx/
├── src/                    # Python interpreter (lexer, parser, AST, evaluator)
│   ├── lexer.py           #   Tokenizer with Unicode, recovery
│   ├── parser.py          #   Pratt parser, 11 precedence levels
│   ├── interpreter.py     #   Tree-walking evaluator
│   ├── ast_nodes.py       #   30+ AST node types
│   ├── token_types.py     #   Token enumeration
│   ├── compiler.py        #   Compilation pipeline
│   ├── borrow_checker.py  #   Ownership analysis
│   └── async_runtime.py   #   Async execution
├── native/nyx.c           # Native C compiler
├── compiler/              # Bootstrap & self-hosting
│   ├── v3_compiler_template.c  # Full C99 compiler (~1500+ lines)
│   ├── v3_seed.ny         # Self-hosting seed
│   └── bootstrap.ny       # v2 bootstrap
├── engines/               # 80+ domain engines (154 .ny files)
│   ├── nygame/           #   Game engine framework
│   ├── nyrender/         #   GPU-driven renderer
│   ├── nyphysics/        #   Deterministic physics
│   ├── nyml/             #   Machine learning
│   ├── nytensor/         #   Tensor computation
│   ├── nygrad/           #   Automatic differentiation
│   ├── nyweb/            #   Web framework
│   ├── nydb/             #   Multi-model database
│   ├── nyhft/            #   High-frequency trading
│   └── ...               #   70+ more engines
├── stdlib/                # 90+ standard library modules
├── language/              # Language specification
│   ├── grammar.ebnf      #   Formal EBNF grammar
│   ├── types.md          #   Type system spec
│   ├── ownership.md      #   Ownership model
│   ├── concurrency.md    #   Concurrency primitives
│   └── MINIMAL_SYNTAX.md #   Minimal syntax variant
├── examples/              # 40+ example programs
├── tests/                 # 180+ test files
├── tools/                 # NYX Studio, editor support
├── configs/production/    # Production deployment configs
├── run.py                 # CLI entry point (interpreter)
├── nyx_runtime.py         # Web runtime server
├── nypm.js                # Package manager
├── Makefile               # Native compiler build
└── package.json           # Project metadata (v5.5.0)
```

---

## Grammar (EBNF excerpt)

```ebnf
program     = { statement } EOF ;
statement   = let_stmt | fn_stmt | class_stmt | if_stmt | for_stmt
            | while_stmt | return_stmt | import_stmt | use_stmt
            | try_stmt | switch_stmt | expr_stmt ;

let_stmt    = "let" IDENT [ ":" type ] "=" expression ;
fn_stmt     = "fn" IDENT "(" params ")" [ "->" type ] block ;
class_stmt  = "class" IDENT [ "<" type_params ">" ] [ ":" trait_list ] block ;

expression  = assignment ;
assignment  = IDENT ( "=" | "+=" | "-=" | "*=" | "/=" | "%=" ) expression
            | ternary ;
ternary     = logical_or [ "?" expression ":" expression ] ;
logical_or  = logical_and { "||" logical_and } ;
logical_and = equality { "&&" equality } ;
equality    = comparison { ( "==" | "!=" ) comparison } ;
comparison  = addition { ( "<" | ">" | "<=" | ">=" ) addition } ;
addition    = multiply { ( "+" | "-" ) multiply } ;
multiply    = unary { ( "*" | "/" | "%" | "**" | "//" ) unary } ;
unary       = ( "!" | "-" | "~" ) unary | call ;
call        = primary { "(" args ")" | "[" expression "]" | "." IDENT } ;
primary     = INT | FLOAT | STRING | BOOL | NULL | IDENT
            | "(" expression ")" | "[" expr_list "]" | "{" kv_list "}"
            | lambda | match_expr ;
```

---

## Key Design Decisions

1. **Dual syntax** &mdash; Developers choose brace or indentation style per preference
2. **Dual imports** &mdash; `import` and `use` are fully interchangeable; no migration friction
3. **Optional semicolons** &mdash; Statement terminators are never required
4. **Ownership by default** &mdash; Move semantics prevent use-after-free at compile time
5. **Engine architecture** &mdash; Domain logic lives in engines, not the core language
6. **Native file generation** &mdash; 14+ formats with zero dependencies
7. **Self-hosting bootstrap** &mdash; Compiler can build itself via `.ny` &rarr; C &rarr; binary chain
8. **Multi-runtime** &mdash; Same `.ny` file works interpreted, compiled, or served as web

---

## Performance

From `benchmarks/` and `docs/BENCHMARKS.md`:

| Benchmark | Nyx (native) | Python | Ratio |
|---|---|---|---|
| Fibonacci(35) | ~0.02s | ~2.5s | **125x** |
| Loop 10M | ~0.03s | ~1.2s | **40x** |
| Array ops 1M | ~0.01s | ~0.8s | **80x** |
| String concat 100K | ~0.005s | ~0.3s | **60x** |

Zero-cost abstractions: generics, traits, and iterators compile to the same machine code as hand-written loops.

---

## License

See [LICENSE](LICENSE) for terms.

**Copyright &copy; 2026 Surya Sekhar Roy. All rights reserved.**

---

<p align="center">
  <strong>Nyx &mdash; Write once. Run everywhere. Replace everything.</strong>
</p>
