# Thread Safety Tests

Run:

```bash
python3 tests/thread_safety_tests/test_thread_safety.py
```

Coverage:
- 1,000 concurrent POST dispatches through Nyx worker pool.
- Multi-process atomic persistence validation (file lock + atomic replace).
- JSON corruption checks after concurrent write pressure.
