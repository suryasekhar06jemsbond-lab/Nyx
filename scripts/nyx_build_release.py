#!/usr/bin/env python3
"""NYX release package manifest builder."""

from __future__ import annotations

import argparse
import json
import pathlib
from datetime import datetime, timezone

ROOT = pathlib.Path.cwd()


def main() -> int:
    parser = argparse.ArgumentParser(description="NYX release build manifest")
    parser.add_argument("--cook-manifest", default="build/cooked/cook_manifest.json")
    parser.add_argument("--out-dir", default="build/release")
    args = parser.parse_args()

    cook_manifest_path = ROOT / args.cook_manifest
    out_dir = ROOT / args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    cook_manifest = json.loads(cook_manifest_path.read_text(encoding="utf-8"))

    release_manifest = {
        "timestamp": datetime.now(tz=timezone.utc).isoformat(),
        "source_cook_manifest": str(cook_manifest_path.relative_to(ROOT)).replace("\\", "/"),
        "asset_count": cook_manifest.get("asset_count", 0),
        "targets": cook_manifest.get("targets", []),
        "status": "candidate",
    }

    out = out_dir / "release_manifest.json"
    out.write_text(json.dumps(release_manifest, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({"ok": True, "release_manifest": str(out.relative_to(ROOT))}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
