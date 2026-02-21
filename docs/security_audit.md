# Security Audit

## Scope

Audited controls:

- CSRF issuance, validation, expiry.
- Replay protection and distributed replay store behavior.
- Rate limiting and bypass resistance.
- Input/schema validation.
- Payload size and content-type enforcement.

## Controls implemented

### CSRF

- Signed token format: `issued_at.nonce.signature`.
- Scope binding includes host.
- TTL enforcement (`csrf_ttl_seconds`).
- Cookie policy: `SameSite=Lax` (+ `Secure` when HTTPS forwarded proto).
- Header validation: `X-NYX-CSRF` (configurable).

### Replay protection

- Request ID header validation (`X-NYX-Request-ID` by default).
- TTL window (`replay_window_seconds`).
- Shared provider transaction support for multi-instance replay safety.

### Request validation

- Composable `RequestValidator` rules.
- JSON schema subset validator:
  - `required`, `properties`, `type`
  - `minLength`/`maxLength`
  - `minimum`/`maximum`
  - `pattern`
  - `minItems`/`maxItems`
- Strict content-type gate.
- Oversized payload rejection (HTTP 413).

### Rate limiting

- Fixed-window limiter with bounded key map.
- Shared coordination support for multi-instance enforcement.
- Rate-limit headers (`X-RateLimit-*`, `RateLimit-*`, `Retry-After`).

## Security harness

Run:

```bash
python3 tests/security_tests/run_security_tests.py
```

Included attacks:

- Injection-like payload validation rejection.
- Header spoofing and rate-limit bypass attempts.
- Large payload DOS attempt.
- CSRF expiry enforcement.

## Recommended production posture

- Keep `csrf=True`, `enforce_replay_id=True`, `rate_limit>0`.
- Keep `strict_content_type=True`.
- Set `max_payload_bytes` based on endpoint profile.
- Use shared coordination provider for multi-instance deployments.
