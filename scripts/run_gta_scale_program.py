#!/usr/bin/env python3
"""Run complete GTA-scale program readiness orchestration."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path.cwd()
REPORT = ROOT / "tests" / "aaa_readiness" / "gta_scale_report.json"


def run_cmd(name: str, cmd: list[str]) -> dict:
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    return {
        "name": name,
        "ok": proc.returncode == 0,
        "returncode": proc.returncode,
        "command": " ".join(cmd),
        "stdout_tail": proc.stdout[-2000:],
        "stderr_tail": proc.stderr[-2000:],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Run GTA-scale production readiness program")
    parser.add_argument("--program", default="configs/production/gta_scale_program.json")
    args = parser.parse_args()

    cfg = json.loads((ROOT / args.program).read_text(encoding="utf-8"))
    plan_cfg = json.loads((ROOT / "configs/production/multi_year_plan.json").read_text(encoding="utf-8"))
    team_cfg = json.loads((ROOT / "configs/production/team_roster.json").read_text(encoding="utf-8"))
    content_cfg = json.loads((ROOT / "configs/production/content_targets.json").read_text(encoding="utf-8"))

    suites = [
        run_cmd("native_hooks", ["python3", "scripts/generate_native_backend_stubs.py"]),
        run_cmd("engine_gates", ["python3", "scripts/run_engine_gates.py", "--iterations", "300"]),
        run_cmd("platform_online_suite", ["python3", "scripts/run_platform_online_suite.py"]),
        run_cmd("content_pipeline", ["python3", "scripts/run_content_pipeline.py"]),
        run_cmd("hardware_validation", ["python3", "scripts/run_hardware_validation_cycles.py"]),
        run_cmd("scale_optimization", ["python3", "scripts/run_continuous_scale_optimization.py", "--days", "180"]),
        run_cmd("multi_year_plan", ["python3", "scripts/plan_multi_year_production.py"]),
        run_cmd("massive_content_backlog", ["python3", "scripts/generate_massive_content_backlog.py"]),
    ]

    total_team = sum(len(v) for v in team_cfg.get("teams", {}).values())
    target_team = sum(int(v) for v in plan_cfg.get("target_headcount", {}).values())
    horizon_ok = int(plan_cfg.get("horizon_years", 0)) >= int(cfg.get("minimum_horizon_years", 4))
    team_ok = target_team >= int(cfg.get("minimum_total_team_size", 700))

    content_ok = True
    for k, v in cfg.get("minimum_content_targets", {}).items():
        if int(content_cfg.get(k, 0)) < int(v):
            content_ok = False

    suite_map = {s["name"]: s["ok"] for s in suites}
    required = cfg.get("required_suites", [])
    required_ok = all(suite_map.get(name, False) for name in required)

    out = {
        "ok": required_ok and horizon_ok and team_ok and content_ok,
        "program_rules": cfg,
        "structural_checks": {
            "horizon_ok": horizon_ok,
            "team_ok": team_ok,
            "content_ok": content_ok,
            "current_team_size": total_team,
            "target_team_size": target_team
        },
        "suite_results": suites,
    }

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": out["ok"], "horizon_ok": horizon_ok, "team_ok": team_ok, "content_ok": content_ok}, indent=2))
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
