# Concurrency Model

## Runtime model

Nyx runtime now uses a **bounded worker-pool dispatch model** plus a **request admission semaphore**:

- Admission gate: `Application._request_slots` (`threading.BoundedSemaphore`)
- Worker queue: `queue.Queue(maxsize=worker_queue_size)`
- Worker pool: `worker_count` daemon threads
- Per-task timeout: `worker_timeout_seconds`

Request path:

1. Request enters `_handle_request`.
2. Admission semaphore is acquired.
3. Request is submitted to the bounded queue as a `WorkerTask`.
4. Worker executes `dispatch()` and signals completion event.
5. Caller waits for completion or timeout.
6. Semaphore is released.

Queue-full result: HTTP 503.
Timeout result: HTTP 504.

## Shared-state safety

Nyx uses explicit synchronization primitives for mutable shared state:

- `PersistentStore`: `RLock` + process-local path lock + inter-process file lock.
- `SQLDatabase`: `RLock` + process-local path lock + inter-process file lock.
- `RateLimiter`: `RLock` for memory mode, atomic provider transactions for shared mode.
- `SecurityMiddleware` replay guard: `RLock` + provider-backed transaction in shared mode.
- `StateStore`: `RLock` + snapshot copy semantics for reads.
- `NyxWebsite.render`: `_render_lock` to protect render/diff caches.
- `WebSocketHub`: `RLock` around room membership changes.

No direct unsynchronized global mutations are used for runtime counters/stores.

## Atomic persistence guarantees

Persistent writes use:

1. Serialize to bytes.
2. Write to temp file.
3. `flush()` + `fsync(file)`.
4. Atomic `os.replace(temp, target)`.
5. Best-effort `fsync(directory)`.
6. Best-effort temp cleanup.

This strategy prevents partial-write JSON corruption on crash/power-loss boundaries.

## Multi-process lock strategy

- In-process lock: shared path lock map (`PersistentStore._path_locks`).
- Cross-process lock: `InterProcessFileLock`.
  - Linux/Unix: `fcntl.flock(LOCK_EX/LOCK_UN)`.
  - Windows: `msvcrt.locking`.

This protects concurrent writers across multiple Nyx instances on shared storage.

## Verification

Run:

```bash
python3 tests/thread_safety_tests/test_thread_safety.py
```

Checks included:

- 1,000 concurrent POST dispatches with atomic counter verification.
- Multi-process write pressure with final consistency check.
- JSON parseability after concurrent write pressure.
