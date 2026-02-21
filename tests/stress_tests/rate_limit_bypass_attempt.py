#!/usr/bin/env python3
"""Rate-limit bypass attempt simulation across pseudo-nodes."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve()
ROOT = HERE
for parent in HERE.parents:
    if (parent / "nyx_runtime.py").is_file():
        ROOT = parent
        break
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from nyx_runtime import InMemoryStateProvider, RateLimiter, Request, Response, SecurityMiddleware


def _mk_req(i: int, spoof_header: str) -> Request:
    return Request(
        method="POST",
        path="/api/action",
        headers={
            "Content-Type": "application/json",
            spoof_header: f"198.51.100.{i % 200}",
            "X-NYX-Request-ID": f"rid-{i}",
        },
        body={"v": i},
        raw_body=b'{"v":1}',
        content_type="application/json",
        client_ip="203.0.113.10",
    )


def _new_node(provider: InMemoryStateProvider, limit: int, window: int) -> SecurityMiddleware:
    limiter = RateLimiter(limit, window, shared_provider=provider, namespace="rate-bypass")
    return SecurityMiddleware(
        enable_csrf=False,
        rate_limiter=limiter,
        enforce_replay_id=True,
        shared_provider=provider,
        shared_namespace="rate-bypass",
    )


def main():
    parser = argparse.ArgumentParser(description="Nyx rate-limit bypass attempt")
    parser.add_argument("--attempts", type=int, default=100)
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--window", type=int, default=60)
    parser.add_argument("--out", type=str, default="tests/stress_tests/rate_limit_bypass_result.json")
    args = parser.parse_args()

    provider = InMemoryStateProvider()
    node_a = _new_node(provider, args.limit, args.window)
    node_b = _new_node(provider, args.limit, args.window)

    def next_handler(_):
        return Response.json(200, {"ok": True})

    spoof_headers = ["X-Forwarded-For", "x-forwarded-for", "X-Real-IP"]
    statuses = []
    for i in range(max(1, args.attempts)):
        node = node_a if i % 2 == 0 else node_b
        req = _mk_req(i, spoof_headers[i % len(spoof_headers)])
        resp = node.process(req, next_handler)
        statuses.append(int(resp.status))

    accepted = sum(1 for s in statuses if s == 200)
    blocked = sum(1 for s in statuses if s == 429)
    bypassed = accepted > int(args.limit)

    payload = {
        "ok": not bypassed,
        "attempts": int(len(statuses)),
        "limit": int(args.limit),
        "accepted": int(accepted),
        "blocked": int(blocked),
        "bypass_success": bool(bypassed),
    }

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
