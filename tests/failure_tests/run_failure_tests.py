#!/usr/bin/env python3
"""Failure-injection tests for Nyx runtime safeguards."""

from __future__ import annotations

import json
import os
import pathlib
import sys
import tempfile
from dataclasses import dataclass

HERE = pathlib.Path(__file__).resolve()
ROOT = HERE
for parent in HERE.parents:
    if (parent / "nyx_runtime.py").is_file():
        ROOT = parent
        break
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import nyx_runtime
from nyx_runtime import Application, HttpRoute, NyxPlugin, NyxWebsite, PersistentStore, Request, WebSocketHub


@dataclass
class CaseResult:
    name: str
    ok: bool
    details: str


class CrashyPlugin(NyxPlugin):
    name = "crashy"
    priority = 50
    fail_open = True

    def setup(self, site):
        raise RuntimeError("plugin setup crash")


class BadConn:
    OPEN = 1
    CLOSED = 3

    def __init__(self):
        self.ready_state = self.OPEN

    def send(self, _payload):
        raise RuntimeError("disconnect")


class GoodConn:
    OPEN = 1
    CLOSED = 3

    def __init__(self):
        self.ready_state = self.OPEN
        self.sent = 0

    def send(self, _payload):
        self.sent += 1


def case_disk_write_interruption() -> CaseResult:
    with tempfile.TemporaryDirectory(prefix="nyx-failure-disk-") as tmpdir:
        path = os.path.join(tmpdir, "store.json")
        store = PersistentStore.new(path)
        store.set("value", 1)

        original_replace = nyx_runtime.os.replace
        fail_once = {"armed": True}

        def flaky_replace(src, dst):
            if fail_once["armed"]:
                fail_once["armed"] = False
                raise OSError("simulated replace failure")
            return original_replace(src, dst)

        nyx_runtime.os.replace = flaky_replace
        try:
            threw = False
            try:
                store.set("value", 2)
            except Exception:
                threw = True
            if not threw:
                return CaseResult("disk_write_interruption", False, "expected write interruption exception")
        finally:
            nyx_runtime.os.replace = original_replace

        # File must remain parseable JSON after interruption.
        with open(path, "r", encoding="utf-8") as fh:
            loaded = json.load(fh)
        if "value" not in loaded:
            return CaseResult("disk_write_interruption", False, "value key missing after interruption")
        return CaseResult("disk_write_interruption", True, f"value_after_failure={loaded.get('value')}")


def case_worker_crash_isolation() -> CaseResult:
    app = Application("worker-crash")
    app.worker_model(64)
    app.worker_pool(workers=8, queue_size=256, timeout_seconds=10)

    def boom(_req):
        raise RuntimeError("simulated worker crash")

    def ok(_req):
        return {"ok": True}

    app.routes.append(HttpRoute("/boom", ["POST"], boom))
    app.routes.append(HttpRoute("/ok", ["POST"], ok))

    app._start_worker_pool()
    try:
        bad_req = Request(method="POST", path="/boom", headers={}, body={}, raw_body=b"{}", content_type="application/json", client_ip="1.1.1.1")
        good_req = Request(method="POST", path="/ok", headers={}, body={}, raw_body=b"{}", content_type="application/json", client_ip="1.1.1.1")

        bad_resp = app._dispatch_via_pool(bad_req)
        if int(bad_resp.status) != 500:
            return CaseResult("worker_crash_isolation", False, f"expected 500 from crashed handler got={bad_resp.status}")

        resp = app._dispatch_via_pool(good_req)
        if int(resp.status) != 200:
            return CaseResult("worker_crash_isolation", False, f"post-crash request failed status={resp.status}")

        stats = app.worker_stats()
        return CaseResult("worker_crash_isolation", True, f"worker_stats={stats}")
    finally:
        app._stop_worker_pool()


def case_plugin_crash_isolation() -> CaseResult:
    site = NyxWebsite("plugin-crash")
    site.pluginContract(False)

    # Should not raise because plugin is fail-open.
    try:
        site.usePlugin(CrashyPlugin())
    except Exception as exc:
        return CaseResult("plugin_crash_isolation", False, f"unexpected exception: {exc}")

    snapshot = site.pluginSnapshot()
    errors = snapshot.get("errors", [])
    if not errors:
        return CaseResult("plugin_crash_isolation", False, "plugin error not recorded")
    return CaseResult("plugin_crash_isolation", True, f"recorded_errors={len(errors)}")


def case_network_disconnect_isolation() -> CaseResult:
    hub = WebSocketHub()
    good = GoodConn()
    bad = BadConn()
    hub.join(good, room="live")
    hub.join(bad, room="live")

    # Broadcast should prune bad connection but keep good connection alive.
    hub.broadcast({"event": "ping"}, room="live")
    remaining = hub.count("live")
    if remaining != 1:
        return CaseResult("network_disconnect_isolation", False, f"expected 1 connection, got {remaining}")
    if good.sent <= 0:
        return CaseResult("network_disconnect_isolation", False, "healthy connection did not receive broadcast")
    return CaseResult("network_disconnect_isolation", True, "bad connection isolated")


def main():
    cases = [
        case_disk_write_interruption,
        case_worker_crash_isolation,
        case_plugin_crash_isolation,
        case_network_disconnect_isolation,
    ]

    results = [fn() for fn in cases]
    ok = all(item.ok for item in results)

    payload = {
        "ok": ok,
        "results": [item.__dict__ for item in results],
    }

    out = "tests/failure_tests/results.json"
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)

    print(json.dumps(payload, indent=2))
    if not ok:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
