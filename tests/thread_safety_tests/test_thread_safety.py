#!/usr/bin/env python3
"""Thread-safety and atomicity tests for Nyx runtime core stores/dispatch."""

from __future__ import annotations

import json
import os
import pathlib
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor, as_completed
from multiprocessing import Process
from typing import Any, Dict

HERE = pathlib.Path(__file__).resolve()
ROOT = HERE
for parent in HERE.parents:
    if (parent / "nyx_runtime.py").is_file():
        ROOT = parent
        break
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from nyx_runtime import Application, HttpRoute, PersistentStore, Request


def _atomic_increment(doc: Dict[str, Any], delta: int = 1) -> int:
    current = int(doc.get("counter", 0) or 0)
    current += int(delta)
    doc["counter"] = current
    return current


def _process_increment_worker(path: str, loops: int):
    store = PersistentStore.new(path)
    for _ in range(int(loops)):
        store.transaction(lambda root: _atomic_increment(root, 1))


class ThreadSafetyTests(unittest.TestCase):
    def test_1000_concurrent_post_requests(self):
        """Simulate 1,000 concurrent POST requests and verify state consistency."""
        total_posts = 1000
        with tempfile.TemporaryDirectory(prefix="nyx-thread-safety-") as tmpdir:
            store_path = os.path.join(tmpdir, "state.json")
            store = PersistentStore.new(store_path)

            app = Application("thread-safety")
            app.worker_model(max_concurrency=512)
            app.worker_pool(workers=32, queue_size=4096, timeout_seconds=20)

            def increment_handler(request: Request):
                payload = request.json()
                delta = int(payload.get("delta", 1) or 1)
                value = store.transaction(lambda root: _atomic_increment(root, delta))
                return {"ok": True, "counter": int(value)}

            app.routes.append(HttpRoute("/api/increment", ["POST"], increment_handler))
            app._start_worker_pool()

            def one_post(i: int):
                req = Request(
                    method="POST",
                    path="/api/increment",
                    headers={"Content-Type": "application/json", "X-Correlation-ID": f"req-{i}"},
                    body={"delta": 1},
                    raw_body=b'{"delta":1}',
                    content_type="application/json",
                    client_ip=f"10.0.0.{(i % 250) + 1}",
                )
                resp = app._dispatch_via_pool(req)
                payload = json.loads(str(resp.body))
                return int(resp.status), int(payload.get("counter", 0))

            try:
                statuses = []
                counters = []
                with ThreadPoolExecutor(max_workers=128) as pool:
                    futures = [pool.submit(one_post, i) for i in range(total_posts)]
                    for fut in as_completed(futures):
                        status, counter_value = fut.result()
                        statuses.append(status)
                        counters.append(counter_value)
            finally:
                app._stop_worker_pool()

            self.assertEqual(len(statuses), total_posts)
            self.assertTrue(all(code == 200 for code in statuses), "all POST requests must return 200")
            self.assertEqual(int(store.get("counter", 0) or 0), total_posts)
            self.assertEqual(max(counters), total_posts)

            # Ensure persisted JSON file is readable and not corrupted.
            with open(store_path, "r", encoding="utf-8") as fh:
                loaded = json.load(fh)
            self.assertEqual(int(loaded.get("counter", 0) or 0), total_posts)

    def test_multi_process_atomic_persistence(self):
        """Verify atomic persistence and file locking with multiple processes writing."""
        proc_count = 8
        loops_per_proc = 250
        expected = proc_count * loops_per_proc

        with tempfile.TemporaryDirectory(prefix="nyx-proc-atomic-") as tmpdir:
            store_path = os.path.join(tmpdir, "shared.json")
            PersistentStore.new(store_path).set("counter", 0)

            procs = [
                Process(target=_process_increment_worker, args=(store_path, loops_per_proc), daemon=True)
                for _ in range(proc_count)
            ]
            for p in procs:
                p.start()
            for p in procs:
                p.join(timeout=40)

            for p in procs:
                self.assertEqual(p.exitcode, 0, f"worker process failed with exitcode={p.exitcode}")

            final_store = PersistentStore.new(store_path)
            final_counter = int(final_store.get("counter", 0) or 0)
            self.assertEqual(final_counter, expected)

            with open(store_path, "r", encoding="utf-8") as fh:
                loaded = json.load(fh)
            self.assertEqual(int(loaded.get("counter", 0) or 0), expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)
