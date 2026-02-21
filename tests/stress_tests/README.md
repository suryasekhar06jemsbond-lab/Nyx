# Stress Tests

Run all:

```bash
python3 tests/stress_tests/http_stress_test.py
python3 tests/stress_tests/websocket_flood_simulation.py
python3 tests/stress_tests/replay_attack_simulation.py
python3 tests/stress_tests/rate_limit_bypass_attempt.py
```

Outputs:
- `tests/stress_tests/http_stress_result.json`
- `tests/stress_tests/websocket_flood_result.json`
- `tests/stress_tests/replay_attack_result.json`
- `tests/stress_tests/rate_limit_bypass_result.json`
