#!/usr/bin/env python3
"""Replay attack simulation for Nyx security middleware."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

HERE = pathlib.Path(__file__).resolve()
ROOT = HERE
for parent in HERE.parents:
    if (parent / "nyx_runtime.py").is_file():
        ROOT = parent
        break
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from nyx_runtime import InMemoryStateProvider, Request, Response, SecurityMiddleware


def _make_request(request_id: str) -> Request:
    body = {"name": "Alice", "email": "alice@example.com"}
    return Request(
        method="POST",
        path="/api/leads",
        headers={
            "Content-Type": "application/json",
            "X-NYX-Request-ID": request_id,
        },
        body=body,
        raw_body=b'{"name":"Alice","email":"alice@example.com"}',
        content_type="application/json",
        client_ip="10.10.10.1",
    )


def main():
    parser = argparse.ArgumentParser(description="Nyx replay attack simulation")
    parser.add_argument("--attempts", type=int, default=200)
    parser.add_argument("--out", type=str, default="tests/stress_tests/replay_attack_result.json")
    args = parser.parse_args()

    provider = InMemoryStateProvider()
    sec = SecurityMiddleware(
        enable_csrf=False,
        enforce_replay_id=True,
        replay_window_seconds=120,
        shared_provider=provider,
        shared_namespace="replay-sim",
    )

    def next_handler(_):
        return Response.json(200, {"ok": True})

    request_id = "replay-fixed-id"

    def one_attempt(_):
        req = _make_request(request_id)
        resp = sec.process(req, next_handler)
        return int(resp.status)

    statuses = []
    with ThreadPoolExecutor(max_workers=32) as pool:
        futures = [pool.submit(one_attempt, i) for i in range(max(1, args.attempts))]
        for fut in as_completed(futures):
            statuses.append(fut.result())

    accepted = sum(1 for s in statuses if s == 200)
    blocked = sum(1 for s in statuses if s == 409)

    payload = {
        "ok": accepted == 1 and blocked == (len(statuses) - 1),
        "attempts": int(len(statuses)),
        "accepted": int(accepted),
        "blocked_replay": int(blocked),
    }

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
