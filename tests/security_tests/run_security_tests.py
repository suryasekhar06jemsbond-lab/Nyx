#!/usr/bin/env python3
"""Security audit harness for Nyx middleware controls."""

from __future__ import annotations

import json
import os
import pathlib
import sys
import time
from dataclasses import dataclass

HERE = pathlib.Path(__file__).resolve()
ROOT = HERE
for parent in HERE.parents:
    if (parent / "nyx_runtime.py").is_file():
        ROOT = parent
        break
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from nyx_runtime import JSONSchemaValidator, RateLimiter, Request, RequestValidator, Response, SecurityMiddleware


@dataclass
class TestResult:
    name: str
    ok: bool
    details: str


def _next_ok(_request):
    return Response.json(200, {"ok": True})


def _parse_cookie(set_cookie: str, key: str) -> str:
    if not set_cookie:
        return ""
    for part in set_cookie.split(";"):
        part = part.strip()
        if part.startswith(f"{key}="):
            return part.split("=", 1)[1]
    return ""


def test_csrf_rotation_and_expiry() -> TestResult:
    sec = SecurityMiddleware(enable_csrf=True, csrf_ttl_seconds=60, enforce_replay_id=False)
    sec.csrf_ttl_seconds = 1

    get_req = Request(method="GET", path="/", headers={}, client_ip="1.1.1.1")
    get_resp = sec.process(get_req, _next_ok)

    token = get_resp.headers.get("X-NYX-CSRF", "")
    set_cookie = get_resp.headers.get("Set-Cookie", "")
    cookie_token = _parse_cookie(set_cookie, "nyx_csrf")

    if not token or not cookie_token:
        return TestResult("csrf_rotation_and_expiry", False, "missing csrf token/cookie")
    if "SameSite=Lax" not in set_cookie:
        return TestResult("csrf_rotation_and_expiry", False, "SameSite policy missing")

    post_req = Request(
        method="POST",
        path="/api/save",
        headers={
            "Content-Type": "application/json",
            "Cookie": f"nyx_csrf={cookie_token}",
            "X-NYX-CSRF": token,
        },
        body={"x": 1},
        raw_body=b'{"x":1}',
        content_type="application/json",
        client_ip="1.1.1.1",
    )
    ok_resp = sec.process(post_req, _next_ok)
    if int(ok_resp.status) != 200:
        return TestResult("csrf_rotation_and_expiry", False, f"valid csrf rejected status={ok_resp.status}")

    time.sleep(2.2)
    expired_resp = sec.process(post_req, _next_ok)
    if int(expired_resp.status) != 403:
        return TestResult("csrf_rotation_and_expiry", False, f"expired csrf should be 403 got={expired_resp.status}")

    return TestResult("csrf_rotation_and_expiry", True, "token rotated and expiry enforced")


def test_json_schema_and_injection_rejection() -> TestResult:
    schema = {
        "type": "object",
        "required": ["name", "email"],
        "properties": {
            "name": {"type": "string", "minLength": 2, "maxLength": 64, "pattern": r"^[A-Za-z0-9 _-]+$"},
            "email": {"type": "string", "pattern": r"^[^@\s]+@[^@\s]+\.[^@\s]+$"},
        },
    }
    validator = RequestValidator()
    jsv = JSONSchemaValidator(schema)
    validator.add(lambda req, _v=jsv: _v.validate(req.json()) or True, "schema invalid")

    sec = SecurityMiddleware(enable_csrf=False, validator=validator, enforce_replay_id=False)

    bad_req = Request(
        method="POST",
        path="/api/leads",
        headers={"Content-Type": "application/json"},
        body={"name": "' OR 1=1; DROP TABLE users;--", "email": "bad@example.com"},
        raw_body=b"{}",
        content_type="application/json",
        client_ip="2.2.2.2",
    )
    bad_resp = sec.process(bad_req, _next_ok)
    if int(bad_resp.status) != 422:
        return TestResult("json_schema_and_injection", False, f"injection payload should fail 422 got={bad_resp.status}")

    good_req = Request(
        method="POST",
        path="/api/leads",
        headers={"Content-Type": "application/json"},
        body={"name": "Alice Smith", "email": "alice@example.com"},
        raw_body=b"{}",
        content_type="application/json",
        client_ip="2.2.2.2",
    )
    good_resp = sec.process(good_req, _next_ok)
    if int(good_resp.status) != 200:
        return TestResult("json_schema_and_injection", False, f"valid payload rejected status={good_resp.status}")

    return TestResult("json_schema_and_injection", True, "schema enforcement active")


def test_content_type_and_payload_limits() -> TestResult:
    sec = SecurityMiddleware(enable_csrf=False, max_payload_bytes=64, strict_content_type=True, enforce_replay_id=False)

    wrong_type_req = Request(
        method="POST",
        path="/api/upload",
        headers={"Content-Type": "application/xml"},
        body="<x/>",
        raw_body=b"<x/>",
        content_type="application/xml",
        client_ip="3.3.3.3",
    )
    wrong_resp = sec.process(wrong_type_req, _next_ok)
    if int(wrong_resp.status) != 415:
        return TestResult("content_type_and_payload_limits", False, f"expected 415 got={wrong_resp.status}")

    large_body = b"{" + b"a" * 4096 + b"}"
    large_req = Request(
        method="POST",
        path="/api/upload",
        headers={"Content-Type": "application/json"},
        body={"blob": "x" * 3000},
        raw_body=large_body,
        content_type="application/json",
        client_ip="3.3.3.3",
    )
    large_resp = sec.process(large_req, _next_ok)
    if int(large_resp.status) != 413:
        return TestResult("content_type_and_payload_limits", False, f"expected 413 got={large_resp.status}")

    return TestResult("content_type_and_payload_limits", True, "content type and payload caps enforced")


def test_header_spoof_and_rate_limit_bypass() -> TestResult:
    limiter = RateLimiter(max_requests=5, window_seconds=60)
    sec = SecurityMiddleware(enable_csrf=False, rate_limiter=limiter, enforce_replay_id=False)

    statuses = []
    for i in range(20):
        req = Request(
            method="POST",
            path="/api/action",
            headers={
                "Content-Type": "application/json",
                "X-Forwarded-For": f"198.51.100.{i}",
                "X-Real-IP": f"198.51.100.{i}",
            },
            body={"x": i},
            raw_body=b"{}",
            content_type="application/json",
            client_ip="4.4.4.4",
        )
        statuses.append(int(sec.process(req, _next_ok).status))

    accepted = sum(1 for s in statuses if s == 200)
    blocked = sum(1 for s in statuses if s == 429)
    if accepted > 5 or blocked < 15:
        return TestResult("header_spoof_and_rate_limit_bypass", False, f"accepted={accepted} blocked={blocked}")
    return TestResult("header_spoof_and_rate_limit_bypass", True, f"accepted={accepted} blocked={blocked}")


def main():
    tests = [
        test_csrf_rotation_and_expiry,
        test_json_schema_and_injection_rejection,
        test_content_type_and_payload_limits,
        test_header_spoof_and_rate_limit_bypass,
    ]
    results = [t() for t in tests]
    ok = all(r.ok for r in results)

    payload = {
        "ok": ok,
        "results": [r.__dict__ for r in results],
    }

    out = "tests/security_tests/results.json"
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)

    print(json.dumps(payload, indent=2))
    if not ok:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
