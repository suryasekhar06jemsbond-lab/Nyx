#!/usr/bin/env python3
"""Generate GTA-scale content backlog manifests."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path.cwd()
OUT_DIR = ROOT / "build" / "content_backlog"


def make_samples(prefix: str, count: int, sample: int = 64) -> list[str]:
    n = min(count, sample)
    return [f"{prefix}_{i:05d}" for i in range(1, n + 1)]


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate massive content backlog plan")
    parser.add_argument("--targets", default="configs/production/content_targets.json")
    args = parser.parse_args()

    targets = json.loads((ROOT / args.targets).read_text(encoding="utf-8"))

    backlog = {
        "ok": True,
        "targets": targets,
        "samples": {
            "primary_missions": make_samples("mission_main", int(targets["primary_missions"])),
            "side_missions": make_samples("mission_side", int(targets["side_missions"])),
            "dynamic_events": make_samples("event_dyn", int(targets["dynamic_events"])),
            "characters": make_samples("npc", int(targets["characters"])),
            "vehicles": make_samples("veh", int(targets["vehicles"])),
            "animation_clips": make_samples("anim", int(targets["animation_clips"])),
            "vo_lines": make_samples("vo", int(targets["vo_lines"])),
            "cinematic_shots": make_samples("cine", int(targets["cinematic_shots"])),
            "audio_events": make_samples("sfx", int(targets["audio_events"])),
        },
        "pipeline_batches": {
            "missions_per_batch": 12,
            "animation_clips_per_batch": 3500,
            "vo_lines_per_batch": 25000,
            "cinematic_shots_per_batch": 1200,
        },
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "content_backlog.json").write_text(json.dumps(backlog, indent=2) + "\n", encoding="utf-8")

    summary = {
        "ok": backlog["ok"],
        "primary_missions": targets["primary_missions"],
        "side_missions": targets["side_missions"],
        "animation_clips": targets["animation_clips"],
        "vo_lines": targets["vo_lines"],
        "cinematic_shots": targets["cinematic_shots"],
    }
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
