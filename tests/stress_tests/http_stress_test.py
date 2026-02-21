#!/usr/bin/env python3
"""HTTP stress test using Nyx worker pool dispatch path."""

from __future__ import annotations

import argparse
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

from nyx_runtime import Application, HttpRoute, PersistentStore, Request


def main():
    parser = argparse.ArgumentParser(description="Nyx HTTP stress test")
    parser.add_argument("--requests", type=int, default=10000)
    parser.add_argument("--concurrency", type=int, default=256)
    parser.add_argument("--out", type=str, default="tests/stress_tests/http_stress_result.json")
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="nyx-http-stress-") as tmpdir:
        store = PersistentStore.new(os.path.join(tmpdir, "state.json"))

        app = Application("http-stress")
        app.worker_model(max_concurrency=max(256, args.concurrency))
        app.worker_pool(workers=max(8, min(64, args.concurrency // 2 or 1)), queue_size=max(4096, args.requests), timeout_seconds=40)

        def submit_handler(request: Request):
            payload = request.json()
            amount = int(payload.get("amount", 1) or 1)

            def _tx(root):
                root["sum"] = int(root.get("sum", 0) or 0) + amount
                return root["sum"]

            total = int(store.transaction(_tx) or 0)
            return {"ok": True, "sum": total}

        app.routes.append(HttpRoute("/api/submit", ["POST"], submit_handler))

        app._start_worker_pool()
        success = 0
        failed = 0
        latencies = []

        def one_call(i: int):
            req = Request(
                method="POST",
                path="/api/submit",
                headers={"Content-Type": "application/json", "X-Correlation-ID": f"stress-{i}"},
                body={"amount": 1},
                raw_body=b'{"amount":1}',
                content_type="application/json",
                client_ip=f"192.168.1.{(i % 250) + 1}",
            )
            started = time.perf_counter()
            resp = app._dispatch_via_pool(req)
            elapsed_ms = (time.perf_counter() - started) * 1000.0
            return int(resp.status), elapsed_ms

        wall_start = time.perf_counter()
        try:
            with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
                futures = [pool.submit(one_call, i) for i in range(args.requests)]
                for fut in as_completed(futures):
                    status, elapsed = fut.result()
                    latencies.append(elapsed)
                    if status == 200:
                        success += 1
                    else:
                        failed += 1
        finally:
            app._stop_worker_pool()

        wall_elapsed = max(0.000001, time.perf_counter() - wall_start)
        payload = {
            "ok": failed == 0,
            "requests": int(args.requests),
            "concurrency": int(args.concurrency),
            "success": int(success),
            "failed": int(failed),
            "rps": round(float(success) / wall_elapsed, 3),
            "latency_ms": {
                "avg": round(sum(latencies) / len(latencies), 3) if latencies else 0.0,
                "max": round(max(latencies), 3) if latencies else 0.0,
            },
            "state_sum": int(store.get("sum", 0) or 0),
        }

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
