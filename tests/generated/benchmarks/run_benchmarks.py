#!/usr/bin/env python3
"""Nyx production benchmark suite (stdlib-only)."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import statistics
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

from nyx_runtime import Application, HttpRoute, PersistentStore, Request, WebSocketHub

try:
    import resource  # type: ignore
except Exception:  # pragma: no cover
    resource = None


def _memory_mb() -> float:
    if resource is None:
        return 0.0
    try:
        rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        if os.sys.platform == "darwin":
            return round(float(rss) / (1024.0 * 1024.0), 3)
        return round(float(rss) / 1024.0, 3)
    except Exception:
        return 0.0


def _percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    sorted_vals = sorted(values)
    idx = int(round((p / 100.0) * (len(sorted_vals) - 1)))
    idx = max(0, min(len(sorted_vals) - 1, idx))
    return sorted_vals[idx]


def benchmark_http(total_requests: int = 5000, concurrency: int = 128) -> dict:
    with tempfile.TemporaryDirectory(prefix="nyx-bench-http-") as tmpdir:
        store = PersistentStore.new(os.path.join(tmpdir, "bench_store.json"))

        app = Application("bench-http")
        app.worker_model(max_concurrency=max(256, concurrency * 2))
        app.worker_pool(workers=max(8, min(64, concurrency // 2 or 1)), queue_size=max(4096, total_requests), timeout_seconds=30)

        def handler(request: Request):
            payload = request.json()
            n = int(payload.get("n", 1) or 1)

            def _tx(doc):
                current = int(doc.get("counter", 0) or 0)
                current += n
                doc["counter"] = current
                return current

            current = int(store.transaction(_tx) or 0)
            return {"ok": True, "counter": current}

        app.routes.append(HttpRoute("/bench", ["POST"], handler))
        app._start_worker_pool()

        durations_ms: list[float] = []
        success = 0
        failed = 0

        def one_request(i: int) -> tuple[bool, float]:
            req = Request(
                method="POST",
                path="/bench",
                headers={"Content-Type": "application/json", "X-Correlation-ID": f"bench-{i}"},
                body={"n": 1},
                raw_body=b'{"n":1}',
                content_type="application/json",
                client_ip=f"172.16.0.{(i % 250) + 1}",
            )
            started = time.perf_counter()
            resp = app._dispatch_via_pool(req)
            elapsed = (time.perf_counter() - started) * 1000.0
            return int(resp.status) == 200, elapsed

        wall_started = time.perf_counter()
        try:
            with ThreadPoolExecutor(max_workers=concurrency) as pool:
                futures = [pool.submit(one_request, i) for i in range(total_requests)]
                for fut in as_completed(futures):
                    ok, elapsed_ms = fut.result()
                    durations_ms.append(elapsed_ms)
                    if ok:
                        success += 1
                    else:
                        failed += 1
        finally:
            app._stop_worker_pool()

        wall_elapsed = max(0.000001, time.perf_counter() - wall_started)

        return {
            "total_requests": total_requests,
            "concurrency": concurrency,
            "success": success,
            "failed": failed,
            "rps": round(float(success) / wall_elapsed, 3),
            "latency_ms": {
                "p50": round(_percentile(durations_ms, 50), 3),
                "p95": round(_percentile(durations_ms, 95), 3),
                "p99": round(_percentile(durations_ms, 99), 3),
                "avg": round(statistics.mean(durations_ms), 3) if durations_ms else 0.0,
                "max": round(max(durations_ms), 3) if durations_ms else 0.0,
            },
            "final_counter": int(store.get("counter", 0) or 0),
        }


class _FakeWebSocket:
    OPEN = 1
    CLOSED = 3

    def __init__(self):
        self.ready_state = self.OPEN
        self.sent = 0

    def send(self, payload):
        self.sent += len(str(payload))


def benchmark_websocket(simulated_connections: int = 10000, broadcast_messages: int = 20) -> dict:
    hub = WebSocketHub()
    before_mem = _memory_mb()

    clients = [_FakeWebSocket() for _ in range(max(1, int(simulated_connections)))]
    for c in clients:
        hub.join(c, room="live")

    started = time.perf_counter()
    for i in range(max(1, int(broadcast_messages))):
        hub.broadcast({"seq": i, "event": "tick"}, room="live")
    elapsed = max(0.000001, time.perf_counter() - started)

    after_mem = _memory_mb()
    active = hub.count("live")

    return {
        "simulated_connections": int(simulated_connections),
        "active_connections": int(active),
        "broadcast_messages": int(broadcast_messages),
        "broadcasts_per_second": round(float(broadcast_messages) / elapsed, 3),
        "memory_before_mb": before_mem,
        "memory_after_mb": after_mem,
        "memory_delta_mb": round(max(0.0, after_mem - before_mem), 3),
    }


def main():
    parser = argparse.ArgumentParser(description="Run Nyx runtime benchmarks")
    parser.add_argument("--requests", type=int, default=5000, help="total HTTP benchmark requests")
    parser.add_argument("--concurrency", type=int, default=128, help="HTTP benchmark concurrency")
    parser.add_argument("--ws-connections", type=int, default=10000, help="simulated websocket connections")
    parser.add_argument("--ws-broadcasts", type=int, default=20, help="number of websocket broadcasts")
    parser.add_argument("--out", type=str, default="tests/generated/benchmarks/results.json", help="output JSON path")
    args = parser.parse_args()

    http_result = benchmark_http(total_requests=args.requests, concurrency=args.concurrency)
    ws_result = benchmark_websocket(
        simulated_connections=args.ws_connections,
        broadcast_messages=args.ws_broadcasts,
    )

    payload = {
        "ok": True,
        "generated_at": int(time.time()),
        "http": http_result,
        "websocket": ws_result,
    }

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)

    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
