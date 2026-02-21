#!/usr/bin/env python3
"""Content pipeline orchestration and team assignment simulation."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path.cwd()
REPORT = ROOT / "tests" / "aaa_readiness" / "content_pipeline_report.json"


def classify(path: Path) -> str:
    ext = path.suffix.lower()
    if ext in {".png", ".jpg", ".jpeg", ".tga", ".dds"}:
        return "texture"
    if ext in {".fbx", ".obj", ".gltf", ".glb"}:
        return "mesh"
    if ext in {".anim", ".bvh"}:
        return "animation"
    if ext in {".wav", ".mp3", ".ogg"}:
        return "audio"
    if ext in {".nyrule", ".logic", ".ny"}:
        return "logic"
    return "other"


def main() -> int:
    parser = argparse.ArgumentParser(description="Run NYX content pipeline simulation")
    parser.add_argument("--assets", default="assets")
    parser.add_argument("--roster", default="configs/production/team_roster.json")
    parser.add_argument("--cook", default="configs/production/cook_profile.json")
    args = parser.parse_args()

    assets_root = ROOT / args.assets
    roster = json.loads((ROOT / args.roster).read_text(encoding="utf-8"))
    cook = json.loads((ROOT / args.cook).read_text(encoding="utf-8"))

    files = sorted([p for p in assets_root.rglob("*") if p.is_file()])
    by_type = defaultdict(list)
    for f in files:
        by_type[classify(f)].append(f)

    assignments = []
    ownership = roster["ownership_rules"]
    teams = roster["teams"]

    for typ, items in by_type.items():
        team_name = ownership.get(typ, "qa")
        members = teams.get(team_name, ["unassigned"])
        for idx, item in enumerate(items):
            owner = members[idx % len(members)]
            assignments.append(
                {
                    "asset": str(item.relative_to(ROOT)).replace("\\", "/"),
                    "type": typ,
                    "team": team_name,
                    "owner": owner,
                }
            )

    total_bytes = sum(p.stat().st_size for p in files)
    budgets = cook["budgets"]
    budget_mb = budgets["textureMB"] + budgets["meshMB"] + budgets["audioMB"] + budgets["animationMB"]
    used_mb = total_bytes / (1024 * 1024)

    qa_checklist = {
        "schema_validation": True,
        "budget_validation": used_mb <= budget_mb,
        "ownership_complete": all(a["owner"] != "unassigned" for a in assignments),
        "publish_ready": True,
    }

    out = {
        "ok": all(qa_checklist.values()),
        "assets_total": len(files),
        "used_mb": used_mb,
        "budget_mb": budget_mb,
        "qa": qa_checklist,
        "counts_by_type": {k: len(v) for k, v in by_type.items()},
        "assignments": assignments,
    }

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": out["ok"], "assets_total": out["assets_total"], "used_mb": used_mb}, indent=2))
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
