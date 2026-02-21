# Failure Tests

Run:

```bash
python3 tests/failure_tests/run_failure_tests.py
```

Scenarios:
- Disk write interruption (atomic persistence integrity).
- Worker handler crash isolation.
- Plugin crash isolation (fail-open contract).
- WebSocket connection failure isolation.
