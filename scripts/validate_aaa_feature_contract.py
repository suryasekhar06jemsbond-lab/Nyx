#!/usr/bin/env python3
"""Validate NYX AAA feature contract coverage across engine manifests and sync layer."""

from __future__ import annotations

import json
import pathlib
import re
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path.cwd()
CONTRACT_PATH = ROOT / "configs" / "production" / "aaa_engine_feature_contract.json"
REPORT_PATH = ROOT / "tests" / "aaa_readiness" / "feature_contract_report.json"
NYGAME_PATH = ROOT / "engines" / "nygame" / "nygame.ny"

CAP_LINE_RE = re.compile(r"^([A-Za-z0-9_]+)\s*=\s*\".*\"\s*$")
PROFILE_CALL_RE = re.compile(r'native_nygame_verify_engine_profile\("([a-z0-9_]+)",\s*"([a-z]+)"\)')


PROFILE_ORDER = ("core", "nocode", "production")


def load_contract() -> dict:
    return json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))


def parse_capabilities_from_pkg(pkg_path: pathlib.Path) -> set[str]:
    lines = pkg_path.read_text(encoding="utf-8").splitlines()
    in_cap = False
    out: set[str] = set()
    for raw in lines:
        line = raw.strip()
        if line == "[capabilities]":
            in_cap = True
            continue
        if in_cap and line.startswith("[") and line.endswith("]") and line != "[capabilities]":
            break
        if not in_cap:
            continue
        m = CAP_LINE_RE.match(line)
        if m:
            out.add(m.group(1))
    return out


def parse_profile_calls(text: str) -> dict[str, set[str]]:
    out: dict[str, set[str]] = {}
    for engine, profile in PROFILE_CALL_RE.findall(text):
        out.setdefault(engine, set()).add(profile)
    return out


def main() -> int:
    if not CONTRACT_PATH.exists():
        print(f"missing contract: {CONTRACT_PATH}")
        return 1
    if not NYGAME_PATH.exists():
        print(f"missing sync layer: {NYGAME_PATH}")
        return 1

    contract = load_contract()
    engines = contract.get("engines", {})

    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "contract": str(CONTRACT_PATH.relative_to(ROOT)),
        "ok": True,
        "engines": {},
        "summary": {
            "engine_count": len(engines),
            "missing_capabilities": 0,
            "missing_profile_checks": 0,
        },
    }

    nygame_profiles = parse_profile_calls(NYGAME_PATH.read_text(encoding="utf-8"))

    for engine, profiles in engines.items():
        pkg = ROOT / "engines" / engine / "ny.pkg"
        missing_capabilities: list[str] = []
        missing_profiles: list[str] = []

        if not pkg.exists():
            missing_capabilities.append("<missing ny.pkg>")
            pkg_caps: set[str] = set()
        else:
            pkg_caps = parse_capabilities_from_pkg(pkg)

        required_caps: set[str] = set()
        for profile in PROFILE_ORDER:
            for cap in profiles.get(profile, []):
                required_caps.add(cap)

        for cap in sorted(required_caps):
            if cap not in pkg_caps:
                missing_capabilities.append(cap)

        seen_profiles = nygame_profiles.get(engine, set())
        for profile in PROFILE_ORDER:
            if profiles.get(profile) and profile not in seen_profiles:
                missing_profiles.append(profile)

        engine_ok = not missing_capabilities and not missing_profiles
        if not engine_ok:
            report["ok"] = False
            report["summary"]["missing_capabilities"] += len(missing_capabilities)
            report["summary"]["missing_profile_checks"] += len(missing_profiles)

        report["engines"][engine] = {
            "pkg": str(pkg.relative_to(ROOT)),
            "required_capabilities": len(required_caps),
            "available_capabilities": len(pkg_caps),
            "missing_capabilities": missing_capabilities,
            "missing_profile_checks": missing_profiles,
            "ok": engine_ok,
        }

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    print(
        json.dumps(
            {
                "ok": report["ok"],
                "engines": report["summary"]["engine_count"],
                "missing_capabilities": report["summary"]["missing_capabilities"],
                "missing_profile_checks": report["summary"]["missing_profile_checks"],
                "report": str(REPORT_PATH.relative_to(ROOT)),
            },
            indent=2,
        )
    )

    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
