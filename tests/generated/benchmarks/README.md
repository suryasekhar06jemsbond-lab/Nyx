# Benchmarks

Run:

```bash
python3 tests/generated/benchmarks/run_benchmarks.py --requests 5000 --concurrency 128 --ws-connections 10000 --ws-broadcasts 20
```

Recorded output is written to `tests/generated/benchmarks/results.json`.

Metrics captured:
- HTTP: RPS, latency p50/p95/p99, average, max.
- WebSocket simulation: active connection count, broadcast throughput, memory delta.
