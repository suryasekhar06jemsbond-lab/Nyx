# NYX Native Backends

This folder contains the production native backend implementation scaffold.

## Generated Contract

Run:

```bash
python3 scripts/generate_native_backend_stubs.py
```

Outputs:

- `native/backends/generated/native_hooks_inventory.json`
- `native/backends/generated/native_hooks_inventory.md`
- `native/backends/generated/nyx_native_hooks.h`
- `native/backends/generated/nyx_native_hooks_stub.c`

## Build Scaffold

`native/backends/CMakeLists.txt` builds `nyx_native_hooks_stub` as the baseline backend library.

## Runtime Scaffold

- `native/backends/src/nyx_backend_runtime.h`
- `native/backends/src/nyx_backend_runtime.c`

This runtime layer is where production domain backends (render/physics/ai/net/audio/logic/etc.) should be initialized and monitored.

## Migration Plan

1. Keep generated contract as source of truth.
2. Replace individual stub functions with domain implementations.
3. Add tests per replaced function and per domain.
4. Keep generator in CI to detect hook contract drift.

## Verification

Run backend and AAA gate checks:

```bash
make native-hooks
python3 scripts/run_engine_gates.py --iterations 300
python3 scripts/run_platform_online_suite.py
python3 scripts/run_content_pipeline.py
python3 scripts/aaa_readiness_check.py --deep
```
