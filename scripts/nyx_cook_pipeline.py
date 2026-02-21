#!/usr/bin/env python3
"""Deterministic NYX content cook pipeline starter."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
from datetime import datetime, timezone


ROOT = pathlib.Path.cwd()


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="NYX deterministic cook pipeline")
    parser.add_argument("--profile", default="configs/production/cook_profile.json")
    parser.add_argument("--assets", default="assets")
    args = parser.parse_args()

    profile_path = ROOT / args.profile
    assets_dir = ROOT / args.assets

    profile = json.loads(profile_path.read_text(encoding="utf-8"))
    output_dir = ROOT / profile["cooking"]["outputDir"]
    cache_dir = ROOT / profile["cooking"]["cacheDir"]
    output_dir.mkdir(parents=True, exist_ok=True)
    cache_dir.mkdir(parents=True, exist_ok=True)

    files = sorted([p for p in assets_dir.rglob("*") if p.is_file()], key=lambda p: str(p.relative_to(ROOT)))

    cooked = []
    for src in files:
        rel = src.relative_to(ROOT)
        digest = sha256_file(src)
        cooked.append(
            {
                "source": str(rel).replace("\\", "/"),
                "sha256": digest,
                "bytes": src.stat().st_size,
            }
        )

    manifest = {
        "timestamp": datetime.now(tz=timezone.utc).isoformat(),
        "profile": str(profile_path.relative_to(ROOT)).replace("\\", "/"),
        "deterministic": bool(profile["cooking"].get("deterministic", False)),
        "incremental": bool(profile["cooking"].get("incremental", False)),
        "targets": profile.get("targets", []),
        "asset_count": len(cooked),
        "assets": cooked,
    }

    out = output_dir / "cook_manifest.json"
    out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({"ok": True, "asset_count": len(cooked), "manifest": str(out.relative_to(ROOT))}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
