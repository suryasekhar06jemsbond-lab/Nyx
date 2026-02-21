# Distributed Mode

## Coordination design

Nyx runtime provides a pluggable coordination API:

- `StateProvider.transaction(namespace, updater)`

Built-ins:

- `InMemoryStateProvider`
- `FileStateProvider`

NyxWebsite integration:

- `site.multiInstance(path, namespace, sync_state)`
- `site.coordinationProvider(provider, namespace, sync_state)`

## What is coordinated

- Rate-limit windows (shared namespace bucket)
- Replay-ID dedupe windows
- Optional shared state snapshots

## Multi-instance rate limiting

Rate limiter uses provider transaction boundaries to ensure a single atomic update per request key/window, avoiding split-brain counters across pseudo-nodes that share the same provider backend.

## Replay coordination

Replay guard stores request IDs in provider namespace with TTL trimming.
Duplicate IDs are blocked across instances that share provider namespace.

## Validation suite

Run:

```bash
python3 tests/multi_node_test_suite/run_multi_node_tests.py
```

Checks:

- Cluster-wide rate-limit correctness.
- Cross-node replay dedupe with TTL eviction.
- Shared-state transaction correctness under concurrency.

## Pluggable backend notes

A production backend should implement `StateProvider.transaction` with:

- Atomic read-modify-write semantics.
- Namespace isolation.
- Durability/consistency guarantees appropriate to deployment topology.
