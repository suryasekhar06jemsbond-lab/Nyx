# Memory Model

## Core principles

Nyx runtime memory behavior follows four rules:

1. Bounded queues for request work.
2. Bounded maps for security/rate state.
3. Copy-on-read snapshots for exposed state.
4. Guarded mutation through locks or provider transactions.

## Bounded resources

- Worker queue: `worker_queue_size` (default 2048).
- Request concurrency: `max_concurrent_requests` (default 256).
- Rate limiter map: `max_keys` with periodic GC.
- Replay cache: TTL-based eviction window.
- WebSocket limits:
  - `idle_timeout_seconds`
  - `max_frame_bytes`
  - `max_messages`
  - `max_send_bytes`

## State and immutability boundaries

- `StateStore.snapshot()` returns deep-copied state.
- `PersistentStore.get()/items()/values()` return safe clones.
- Observability snapshots are deep-copied from internal counters.

These boundaries prevent accidental shared mutable references from escaping.

## Render memory controls

- Diff payloads capped by `diff_max_updates`.
- Render cache guarded by `_render_lock`.
- Previous render trees retained by path only.

## Persistence memory safety

Disk stores serialize complete dict snapshots and commit atomically.
Partial or torn JSON writes are prevented by temp-write + fsync + rename semantics.

## Monitoring memory

Metrics endpoint (`/__nyx/metrics`) includes:

- Process RSS estimate (`process.memory_mb`)
- Worker queue utilization
- Request counters and latency
- WebSocket active counts

Use benchmark/stress outputs to estimate memory growth at target concurrency.
