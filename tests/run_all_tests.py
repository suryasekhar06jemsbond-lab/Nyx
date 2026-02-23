#!/usr/bin/env python3
"""
Nyx tests folder orchestrator (runtime-driven).

This runner validates tests by invoking the native Nyx runtime instead of
Python-side lexer/parser/interpreter modules.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TESTS_DIR = ROOT / "tests"
CHECKUP_DIR = TESTS_DIR / "checkup"


def find_runtime() -> Path | None:
    candidates = [
        ROOT / "build" / "nyx.exe",
        ROOT / "nyx.exe",
        ROOT / "build" / "nyx",
        ROOT / "nyx",
    ]
    for c in candidates:
        if c.exists():
            return c
    return None


def run_cmd(args: list[str], timeout: int = 10) -> tuple[int, str, str]:
    proc = subprocess.run(
        args,
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    return proc.returncode, proc.stdout, proc.stderr


def main() -> int:
    runtime = find_runtime()
    if not runtime:
        print("FAIL: Nyx runtime not found (expected build/nyx(.exe) or nyx(.exe))")
        return 1

    CHECKUP_DIR.mkdir(parents=True, exist_ok=True)

    parse_failures: list[dict[str, str | int]] = []
    exec_failures: list[dict[str, str | int]] = []

    ny_files = sorted(TESTS_DIR.rglob("*.ny"))
    top_level_ny = sorted(TESTS_DIR.glob("*.ny"))

    for f in ny_files:
        code, out, err = run_cmd([str(runtime), "--parse-only", str(f)], timeout=10)
        if code != 0:
            parse_failures.append(
                {
                    "file": str(f),
                    "exit_code": code,
                    "stderr": (err or out).strip()[:500],
                }
            )

    for f in top_level_ny:
        code, out, err = run_cmd([str(runtime), str(f)], timeout=10)
        if code != 0:
            exec_failures.append(
                {
                    "file": str(f),
                    "exit_code": code,
                    "stderr": (err or out).strip()[:500],
                }
            )

    summary = {
        "runtime": str(runtime),
        "parse_total": len(ny_files),
        "parse_fail": len(parse_failures),
        "exec_total": len(top_level_ny),
        "exec_fail": len(exec_failures),
        "parse_failures": parse_failures,
        "exec_failures": exec_failures,
    }

    report_path = CHECKUP_DIR / "python_runtime_suite_latest.json"
    report_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print("=" * 60)
    print("NYX TESTS FOLDER RUNTIME CHECK")
    print("=" * 60)
    print(f"Runtime: {runtime}")
    print(f"Parse sweep: {summary['parse_total']} total, {summary['parse_fail']} failed")
    print(f"Exec sweep : {summary['exec_total']} total, {summary['exec_fail']} failed")
    print(f"Report: {report_path}")

    if parse_failures:
        print("\nParse failures:")
        for item in parse_failures[:20]:
            print(f"- {item['file']} :: {item['stderr']}")

    if exec_failures:
        print("\nExecution failures:")
        for item in exec_failures[:20]:
            print(f"- {item['file']} :: {item['stderr']}")

    return 0 if (not parse_failures and not exec_failures) else 1


if __name__ == "__main__":
    sys.exit(main())
