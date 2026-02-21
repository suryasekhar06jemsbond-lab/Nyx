# Security Tests

Run:

```bash
python3 tests/security_tests/run_security_tests.py
```

This harness validates:
- CSRF token issuance/expiry and cookie policy.
- JSON schema validation and injection rejection.
- Payload-size and content-type hardening.
- Header spoofing and rate-limit bypass attempts.
