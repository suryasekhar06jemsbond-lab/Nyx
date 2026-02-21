# Latest Stress Run

## HTTP stress

From `tests/stress_tests/http_stress_result.json`:

- Requests: 10000
- Concurrency: 256
- Success: 10000
- Failed: 0
- RPS: 124.236
- Avg latency: 2034.23 ms
- Max latency: 3586.97 ms

## WebSocket flood

From `tests/stress_tests/websocket_flood_result.json`:

- Connections before: 10000
- Connections after: 9980
- Broadcasts: 100
- Throughput: 2396.32 broadcasts/sec
- Pruned unstable connections: 20

## Replay attack simulation

From `tests/stress_tests/replay_attack_result.json`:

- Attempts: 200
- Accepted: 1
- Blocked replay: 199

## Rate-limit bypass attempt

From `tests/stress_tests/rate_limit_bypass_result.json`:

- Attempts: 100
- Limit: 20
- Accepted: 20
- Blocked: 80
- Bypass success: false
