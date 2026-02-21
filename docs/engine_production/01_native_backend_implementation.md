# 01 Native Backend Implementation

## Objective

Implement all engine-facing `native_*` hooks as stable, testable, platform-ready runtime services.

## Current State

- Hook declarations are defined in engine modules.
- Contract extraction is automated via `scripts/generate_native_backend_stubs.py`.
- Current generated inventory includes 111 hooks in:
  - `native/backends/generated/native_hooks_inventory.json`

## Hook Domains

### Core Runtime

- Memory telemetry and SIMD runtime hooks.
- Schema compilation and no-code pipeline validation hooks.
- Optimization feedback hooks.

### Rendering

- Material graph compile/register hooks.
- Render pipeline graph compile hooks.
- Runtime quality tier application hooks.

### Physics

- Constraint graph compile hooks.
- Property template application hooks.
- Auto tuning and destruction rule compile hooks.

### World

- World rules compile hooks.
- Streaming prediction hooks.
- Economy simulation hooks.

### AI

- Intent->behavior compilation hooks.
- Sandbox execution hooks.

### Networking

- Replication autodiscovery hooks.
- Interest zone generation hooks.
- Deterministic desync validation hooks.

### Audio

- Acoustic zone graph compile hooks.
- Emotional music state resolver hooks.

### Animation

- Intent motion synthesis hooks.
- Physics adaptation hooks.

### Declarative Logic

- Rule generation/validation hooks.
- Rule graph compile hooks.
- Runtime mutation and optimization hooks.

## Implementation Architecture

## Layer 1: ABI Layer

- Generated C header: `native/backends/generated/nyx_native_hooks.h`
- Generated default implementations: `native/backends/generated/nyx_native_hooks_stub.c`
- Runtime registry wrapper: `native/backends/src/nyx_backend_runtime.c`

## Layer 2: Service Layer (per engine)

Create submodules under `native/backends/src/`:

- `core/`
- `render/`
- `physics/`
- `world/`
- `ai/`
- `net/`
- `audio/`
- `anim/`
- `logic/`

Each service must expose:

- deterministic init/shutdown
- thread-safety mode (single-threaded, lock-free, job-safe)
- profiler labels for every callable path
- failure policy (retry, fallback, fail-fast)

## Layer 3: Platform Adapter

Per-platform adapter boundaries:

- Windows (DX12 + WASAPI + WinSock)
- Linux (Vulkan + ALSA/Pulse + epoll)
- Console adapters (vendor SDK wrappers)

## Required Hook Guarantees

Each hook needs a guarantee document row with:

- latency budget
- allocation policy (no alloc/frame alloc/pool)
- deterministic behavior class
- recovery behavior on failure
- telemetry dimensions

## Build System

- Backend scaffold CMake file: `native/backends/CMakeLists.txt`
- Build outputs:
  - `nyx_backend_core` static/shared lib
  - platform-specific plugin libs (future)

## Test Plan

### Unit

- Hook return contract tests.
- Null/invalid argument tests.
- Determinism repeatability tests.

### Integration

- Engine-to-hook path tests by module.
- Hot-reload and pipeline update tests.
- Cross-engine interaction tests (`nyrender` + `nyphysics` + `nylogic`).

### Stress

- 8h/24h soak runs with memory leak gates.
- thread-safety race detection.
- randomized fuzz invocation of hook inputs.

## Delivery Plan

1. Freeze inventory from generator.
2. Assign implementation ownership by domain.
3. Replace generated stubs incrementally with service-backed functions.
4. Run gate tests per domain before enabling in production profiles.
5. Run full-system performance and determinism gates.

## Exit Criteria

- 100% non-stub implementation for production targets.
- 95%+ automated hook coverage.
- no critical stability regressions in 24h soak.
