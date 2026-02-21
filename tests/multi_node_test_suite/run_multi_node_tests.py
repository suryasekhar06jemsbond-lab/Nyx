#!/usr/bin/env python3
"""Multi-instance and distributed-coordination correctness checks."""

from __future__ import annotations

import json
import os
import pathlib
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

HERE = pathlib.Path(__file__).resolve()
ROOT = HERE
for parent in HERE.parents:
    if (parent / "nyx_runtime.py").is_file():
        ROOT = parent
        break
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from nyx_runtime import FileStateProvider, RateLimiter, Request, Response, SecurityMiddleware


def _mk_req(request_id: str) -> Request:
    return Request(
        method="POST",
        path="/api/txn",
        headers={
            "Content-Type": "application/json",
            "X-NYX-Request-ID": request_id,
        },
        body={"ok": True},
        raw_body=b'{"ok":true}',
        content_type="application/json",
        client_ip="10.0.0.10",
    )


def main():
    with tempfile.TemporaryDirectory(prefix="nyx-multi-node-") as tmpdir:
        coord_path = os.path.join(tmpdir, "coordination.json")
        provider = FileStateProvider(coord_path)

        # Test distributed rate limiting across two pseudo-nodes.
        node_a_limiter = RateLimiter(10, 60, shared_provider=provider, namespace="cluster-rate")
        node_b_limiter = RateLimiter(10, 60, shared_provider=provider, namespace="cluster-rate")

        statuses = []
        for i in range(20):
            limiter = node_a_limiter if i % 2 == 0 else node_b_limiter
            statuses.append(bool(limiter.allow("203.0.113.7:POST:/api/txn")))
        accepted = sum(1 for s in statuses if s)
        blocked = len(statuses) - accepted

        # Test distributed replay protection across two pseudo-nodes.
        node_a_sec = SecurityMiddleware(
            enable_csrf=False,
            enforce_replay_id=True,
            replay_window_seconds=1,
            shared_provider=provider,
            shared_namespace="cluster-replay",
        )
        node_b_sec = SecurityMiddleware(
            enable_csrf=False,
            enforce_replay_id=True,
            replay_window_seconds=1,
            shared_provider=provider,
            shared_namespace="cluster-replay",
        )

        def next_handler(_req):
            return Response.json(200, {"ok": True})

        first = node_a_sec.process(_mk_req("RID-1"), next_handler)
        duplicate = node_b_sec.process(_mk_req("RID-1"), next_handler)
        time.sleep(1.2)
        after_ttl = node_b_sec.process(_mk_req("RID-1"), next_handler)

        # Test coordinated shared state increments across nodes.
        def tx_increment(_):
            def _update(bucket):
                bucket["hits"] = int(bucket.get("hits", 0) or 0) + 1
                return int(bucket["hits"])
            return provider.transaction("cluster-state", _update)

        with ThreadPoolExecutor(max_workers=32) as pool:
            futures = [pool.submit(tx_increment, i) for i in range(200)]
            for fut in as_completed(futures):
                fut.result()

        shared_hits = provider.transaction("cluster-state", lambda bucket: int(bucket.get("hits", 0) or 0))

        payload = {
            "ok": (
                accepted <= 10
                and int(first.status) == 200
                and int(duplicate.status) == 409
                and int(after_ttl.status) == 200
                and int(shared_hits) == 200
            ),
            "distributed_rate_limit": {
                "attempts": 20,
                "accepted": int(accepted),
                "blocked": int(blocked),
                "limit": 10,
            },
            "distributed_replay": {
                "first_status": int(first.status),
                "duplicate_status": int(duplicate.status),
                "after_ttl_status": int(after_ttl.status),
            },
            "shared_state": {
                "hits": int(shared_hits),
            },
            "coordination_path": coord_path,
        }

    out = "tests/multi_node_test_suite/results.json"
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)

    print(json.dumps(payload, indent=2))
    if not payload["ok"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
