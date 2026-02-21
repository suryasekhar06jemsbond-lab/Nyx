#!/usr/bin/env python3
"""AAA readiness artifact checks with optional deep execution mode."""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path.cwd()
REPORT_PATH = ROOT / "tests" / "aaa_readiness" / "latest_report.json"

REQUIRED = {
    "native_backend": [
        "native/backends/generated/native_hooks_inventory.json",
        "native/backends/generated/nyx_native_hooks.h",
        "native/backends/generated/nyx_native_hooks_stub.c",
        "native/backends/CMakeLists.txt",
        "configs/production/aaa_engine_feature_contract.json",
        "scripts/sync_engine_capabilities.py",
        "scripts/validate_aaa_feature_contract.py",
    ],
    "editor_toolchain": [
        "tools/nyx_studio/README.md",
        "tools/nyx_studio/editor_manifest.yaml",
        "tools/nyx_studio/studio_server.py",
        "tools/nyx_studio/web/index.html",
        "configs/production/cook_profile.json",
    ],
    "optimization_stability": [
        "docs/engine_production/03_optimization_stability.md",
        "tests/aaa_readiness/readiness_matrix.yaml",
        "scripts/run_engine_gates.py",
        "configs/production/gate_thresholds.json",
    ],
    "platform_online": [
        "docs/engine_production/04_platform_online_readiness.md",
        "configs/production/liveops_slo.yaml",
        "scripts/run_platform_online_suite.py",
        "configs/production/platform_cert_matrix.json",
        "configs/production/anti_cheat_rules.json",
    ],
    "content_pipeline": [
        "docs/engine_production/05_content_pipeline_team_scale.md",
        "docs/engine_production/AAA_WORK_BREAKDOWN.yaml",
        "scripts/run_content_pipeline.py",
        "configs/production/team_roster.json",
        "configs/production/content_targets.json",
    ],
    "gta_scale_program": [
        "scripts/run_gta_scale_program.py",
        "scripts/run_hardware_validation_cycles.py",
        "scripts/run_continuous_scale_optimization.py",
        "scripts/plan_multi_year_production.py",
        "scripts/generate_massive_content_backlog.py",
        "configs/production/gta_scale_program.json",
        "configs/production/multi_year_plan.json",
        "configs/production/hardware_matrix.json",
    ],
}


def exists(rel: str) -> bool:
    return (ROOT / rel).exists()


def check_hooks() -> tuple[int, bool]:
    p = ROOT / "native/backends/generated/native_hooks_inventory.json"
    if not p.exists():
        return 0, False
    data = json.loads(p.read_text(encoding="utf-8"))
    return len(data), len(data) >= 100


def run_deep_suites() -> dict:
    suites = [
        ("feature_contract", ["python3", "scripts/validate_aaa_feature_contract.py"]),
        ("engine_gates", ["python3", "scripts/run_engine_gates.py", "--iterations", "200"]),
        ("platform_online", ["python3", "scripts/run_platform_online_suite.py"]),
        ("content_pipeline", ["python3", "scripts/run_content_pipeline.py"]),
        ("hardware_validation", ["python3", "scripts/run_hardware_validation_cycles.py"]),
        ("scale_optimization", ["python3", "scripts/run_continuous_scale_optimization.py", "--days", "120"]),
        ("production_plan", ["python3", "scripts/plan_multi_year_production.py"]),
        ("content_backlog", ["python3", "scripts/generate_massive_content_backlog.py"]),
        ("gta_scale_program", ["python3", "scripts/run_gta_scale_program.py"]),
    ]
    out = {}
    for name, cmd in suites:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        out[name] = {
            "ok": proc.returncode == 0,
            "returncode": proc.returncode,
            "stdout_tail": proc.stdout[-2000:],
            "stderr_tail": proc.stderr[-2000:],
            "command": " ".join(cmd),
        }
    return out


def main() -> int:
    deep = "--deep" in sys.argv
    report = {
        "timestamp": datetime.now(tz=timezone.utc).isoformat(),
        "mode": "deep" if deep else "quick",
        "tracks": {},
        "summary": {
            "ok": True,
            "missing_files": 0,
            "hook_count": 0,
        },
    }

    for track, files in REQUIRED.items():
        missing = [f for f in files if not exists(f)]
        report["tracks"][track] = {
            "ok": len(missing) == 0,
            "missing": missing,
            "required_count": len(files),
        }
        if missing:
            report["summary"]["ok"] = False
            report["summary"]["missing_files"] += len(missing)

    hook_count, hooks_ok = check_hooks()
    report["summary"]["hook_count"] = hook_count
    report["summary"]["hooks_ok"] = hooks_ok
    if not hooks_ok:
        report["summary"]["ok"] = False

    if deep:
        deep_results = run_deep_suites()
        report["deep_suites"] = deep_results
        report["summary"]["deep_suite_failures"] = sum(1 for x in deep_results.values() if not x["ok"])
        if report["summary"]["deep_suite_failures"] > 0:
            report["summary"]["ok"] = False
    else:
        report["summary"]["deep_suite_failures"] = None

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    print(json.dumps(report["summary"], indent=2))
    return 0 if report["summary"]["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
