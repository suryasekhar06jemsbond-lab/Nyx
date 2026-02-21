#!/usr/bin/env python3
"""WebSocket flood simulation for Nyx broadcast hub behavior."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import time

HERE = pathlib.Path(__file__).resolve()
ROOT = HERE
for parent in HERE.parents:
    if (parent / "nyx_runtime.py").is_file():
        ROOT = parent
        break
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from nyx_runtime import WebSocketHub


class FakeConn:
    OPEN = 1
    CLOSED = 3

    def __init__(self, fail_after: int = -1):
        self.ready_state = self.OPEN
        self._sent = 0
        self._fail_after = int(fail_after)

    def send(self, payload):
        self._sent += 1
        if self._fail_after >= 0 and self._sent > self._fail_after:
            raise RuntimeError("simulated disconnect")



def main():
    parser = argparse.ArgumentParser(description="Nyx websocket flood simulation")
    parser.add_argument("--connections", type=int, default=10000)
    parser.add_argument("--broadcasts", type=int, default=100)
    parser.add_argument("--out", type=str, default="tests/stress_tests/websocket_flood_result.json")
    args = parser.parse_args()

    hub = WebSocketHub()
    conns = []
    for i in range(max(1, args.connections)):
        # every 500th connection is unstable to test cleanup.
        fail_after = 2 if i % 500 == 0 else -1
        c = FakeConn(fail_after=fail_after)
        conns.append(c)
        hub.join(c, room="live")

    before = hub.count("live")
    started = time.perf_counter()
    for i in range(max(1, args.broadcasts)):
        hub.broadcast({"seq": i, "event": "tick"}, room="live")
    elapsed = max(0.000001, time.perf_counter() - started)
    after = hub.count("live")

    payload = {
        "ok": True,
        "connections_before": int(before),
        "connections_after": int(after),
        "broadcasts": int(args.broadcasts),
        "broadcasts_per_second": round(float(args.broadcasts) / elapsed, 3),
        "unstable_connections_pruned": int(before - after),
    }

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
