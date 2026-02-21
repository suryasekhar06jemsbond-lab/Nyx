#!/usr/bin/env python3
"""Generate multi-year team and phase production roadmap."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path.cwd()
OUT_DIR = ROOT / "build" / "production_plan"


def main() -> int:
    parser = argparse.ArgumentParser(description="Plan multi-year AAA production")
    parser.add_argument("--plan", default="configs/production/multi_year_plan.json")
    parser.add_argument("--roster", default="configs/production/team_roster.json")
    args = parser.parse_args()

    plan = json.loads((ROOT / args.plan).read_text(encoding="utf-8"))
    roster = json.loads((ROOT / args.roster).read_text(encoding="utf-8"))

    current = sum(len(v) for v in roster.get("teams", {}).values())
    target = sum(int(v) for v in plan.get("target_headcount", {}).values())
    delta = max(target - current, 0)

    months = sum(int(p.get("duration_months", 0)) for p in plan.get("phases", []))
    hire_per_month = (delta / months) if months else 0.0

    phase_rows = []
    running_month = 0
    cumulative_hires = 0.0
    for phase in plan.get("phases", []):
        duration = int(phase.get("duration_months", 0))
        phase_hires = hire_per_month * duration
        cumulative_hires += phase_hires
        row = {
            "phase": phase.get("name", "unknown"),
            "duration_months": duration,
            "start_month": running_month + 1,
            "end_month": running_month + duration,
            "focus": phase.get("focus", []),
            "planned_hires": round(phase_hires),
            "projected_team_size": current + round(cumulative_hires),
        }
        phase_rows.append(row)
        running_month += duration

    out = {
        "ok": months >= 48 and target >= 700,
        "current_team_size": current,
        "target_team_size": target,
        "hiring_needed": delta,
        "timeline_months": months,
        "hiring_per_month": round(hire_per_month, 2),
        "phases": phase_rows,
        "regional_studios": plan.get("regional_studios", []),
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "multi_year_roadmap.json").write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")

    md_lines = [
        "# Multi-Year Production Roadmap",
        "",
        f"- current_team_size: {out['current_team_size']}",
        f"- target_team_size: {out['target_team_size']}",
        f"- hiring_needed: {out['hiring_needed']}",
        f"- timeline_months: {out['timeline_months']}",
        f"- hiring_per_month: {out['hiring_per_month']}",
        "",
        "## Phases",
    ]
    for p in phase_rows:
        md_lines.append(f"- {p['phase']}: months {p['start_month']}-{p['end_month']}, hires {p['planned_hires']}, team {p['projected_team_size']}")
    (OUT_DIR / "multi_year_roadmap.md").write_text("\n".join(md_lines) + "\n", encoding="utf-8")

    print(json.dumps({"ok": out["ok"], "timeline_months": months, "target_team_size": target}, indent=2))
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
