# Security Best Practices

## Defaults to keep enabled

- CSRF: enabled.
- Replay protection: enabled and enforced.
- Rate limiting: enabled.
- Strict content type: enabled.
- Payload size cap: enabled.

## Request hygiene

1. Require `X-NYX-Request-ID` on all mutating API calls.
2. Use JSON schema validation on every mutating endpoint.
3. Keep payload limits small per endpoint class.
4. Reject unknown content-types.

## CSRF hygiene

1. Always include token in `X-NYX-CSRF`.
2. Keep TTL low enough for threat model.
3. Serve behind HTTPS and preserve secure cookie attributes.

## Multi-instance hygiene

1. Use shared coordination provider for replay/rate consistency.
2. Keep namespace scoped per environment/app.
3. Avoid mixed namespaces between staging and production.

## Operational hygiene

1. Scrape `/__nyx/metrics` and `/__nyx/health` continuously.
2. Track `error_rate` and queue utilization alerts.
3. Review `/__nyx/errors` for repeated validator/security failures.
4. Run security harness before each release.

## Release gate

Before promoting build:

```bash
python3 tests/security_tests/run_security_tests.py
python3 tests/failure_tests/run_failure_tests.py
python3 tests/multi_node_test_suite/run_multi_node_tests.py
```

Require all checks to pass.
