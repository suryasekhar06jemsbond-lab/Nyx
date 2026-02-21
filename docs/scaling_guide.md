# Scaling Guide

## High-traffic deployment profile

Target profile:

- 10k concurrent client sessions (mix of HTTP + WebSocket).
- Multi-instance deployment behind a load balancer.

## Recommended runtime settings

```nyx
site = site.workerModel(1024);
site = site.wsPolicy(120, 262144, 4096, 262144);
site = site.securityLayer(true, 600, 60, null, 7200, "X-NYX-Request-ID", 120, true, 1048576, true, null);
site = site.multiInstance(".nyx/cluster_state.json", "prod-cluster", true);
site = site.observability(true, true, "/__nyx/metrics", "/__nyx/errors", "/__nyx/plugins", 1000);
```

## Horizontal scale model

1. Run multiple Nyx processes.
2. Put behind L4/L7 load balancer.
3. Use shared coordination provider namespace.
4. Scrape per-node metrics and aggregate.
5. Alert on `error_rate`, `worker.utilization`, `ws_connections_open`.

## Capacity validation workflow

1. Run `tests/generated/benchmarks/run_benchmarks.py`.
2. Run `tests/stress_tests/http_stress_test.py`.
3. Run `tests/stress_tests/websocket_flood_simulation.py`.
4. Compare p95/p99 latency and queue utilization against SLO.
5. Increase worker/instance count until headroom target is met.

## Backpressure strategy

- Keep queue bounded.
- Return 503 quickly when saturated.
- Preserve low tail latency rather than allowing unbounded queue growth.

## Failure isolation strategy

- Worker task exceptions are isolated per request.
- Plugin errors can be fail-open.
- WebSocket failures isolate per connection.
- Health endpoint reports degraded status on runtime stress/errors.
