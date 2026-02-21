# 03 Optimization And Stability Program

## Objective

Establish production performance and reliability with measurable budgets and enforced gates.

## Budgets

## Frame Budget (60 FPS target)

- total frame: 16.67 ms
- render: <= 8.0 ms
- physics: <= 3.0 ms
- AI: <= 2.0 ms
- audio: <= 1.0 ms
- streaming + misc: <= 2.0 ms

## Memory Budget

- hard cap per platform tier
- streaming pool cap
- frame allocator cap
- transient RT buffers cap

## Profiling Stack

- CPU timeline profiler
- GPU timer queries
- allocation telemetry
- IO latency telemetry
- network jitter/loss telemetry

## Instrumentation Requirements

- Every `native_*` hook emits trace events.
- Every subsystem emits frame budget counters.
- Counters labeled by world zone, scenario, and platform profile.

## Determinism Program

### Physics

- fixed-step authoritative mode
- checksum per frame
- replay validation for divergence

### Network

- server/client checksum comparison
- desync source logging

### Logic

- deterministic rule evaluation order
- hash-stable rule graph compile

## Streaming Stability

- IO queue depth guardrails
- predictive load hit-rate tracking
- eviction correctness tests

## Crash Resilience

- crash dump capture
- watchdog restart path
- journal replay recovery
- fail-safe fallback assets

## Automated Gates

Use `tests/aaa_readiness/readiness_matrix.yaml` as source of CI pass/fail criteria:

- p95/p99 frame time
- memory leak threshold
- crash-free soak duration
- determinism mismatch rate
- streaming miss spikes

## Test Matrix

1. Microbenchmarks per subsystem
2. Scenario benchmarks (combat, driving, dense city)
3. Soak (8h, 24h, 72h)
4. Fault injection (asset loss, network loss, delayed IO)
5. Replay determinism comparisons

## Operational Responses

- automatic quality tier fallback when thermal/GPU pressure is sustained
- controlled subsystem degradation policy
- incident triage templates with owner rotation

## Exit Criteria

- all budget gates green across target tiers
- deterministic replay pass rate > 99.99%
- zero critical crashes in 24h soak
- stable streaming under worst-case traversal scenarios
