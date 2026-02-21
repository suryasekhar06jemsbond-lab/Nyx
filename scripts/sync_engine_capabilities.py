#!/usr/bin/env python3
"""Sync engine ny.pkg capability sections with AAA feature contract."""

from __future__ import annotations

import json
import pathlib
import re

ROOT = pathlib.Path.cwd()
CONTRACT_PATH = ROOT / "configs" / "production" / "aaa_engine_feature_contract.json"


def humanize(key: str) -> str:
    words = key.replace("_", " ").split()
    if not words:
        return key
    return " ".join(words)


def load_contract() -> dict[str, set[str]]:
    data = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    out: dict[str, set[str]] = {}
    for engine, profiles in data.get("engines", {}).items():
        caps: set[str] = set()
        for profile_caps in profiles.values():
            for cap in profile_caps:
                caps.add(cap)
        out[engine] = caps
    return out


def parse_existing_capability_keys(lines: list[str], start: int, end: int) -> set[str]:
    keys: set[str] = set()
    rx = re.compile(r"^([A-Za-z0-9_]+)\s*=\s*\".*\"\s*$")
    for i in range(start, end):
        line = lines[i].strip()
        m = rx.match(line)
        if m:
            keys.add(m.group(1))
    return keys


def find_capabilities_section(lines: list[str]) -> tuple[int, int] | None:
    start = -1
    end = len(lines)
    for i, raw in enumerate(lines):
        line = raw.strip()
        if line == "[capabilities]":
            start = i
            continue
        if start >= 0 and line.startswith("[") and line.endswith("]") and line != "[capabilities]":
            end = i
            break
    if start < 0:
        return None
    return start, end


def sync_engine(engine: str, required_caps: set[str]) -> tuple[int, pathlib.Path]:
    pkg_path = ROOT / "engines" / engine / "ny.pkg"
    if not pkg_path.exists():
        raise FileNotFoundError(f"missing package file: {pkg_path}")

    lines = pkg_path.read_text(encoding="utf-8").splitlines()
    section = find_capabilities_section(lines)
    if section is None:
        raise ValueError(f"[capabilities] section not found: {pkg_path}")
    start, end = section

    existing = parse_existing_capability_keys(lines, start + 1, end)
    missing = sorted(cap for cap in required_caps if cap not in existing)
    if not missing:
        return 0, pkg_path

    insert_at = end
    new_lines = []
    for cap in missing:
        new_lines.append(f'{cap} = "AAA contract: {humanize(cap)}"')

    updated = lines[:insert_at] + new_lines + lines[insert_at:]
    pkg_path.write_text("\n".join(updated) + "\n", encoding="utf-8")
    return len(missing), pkg_path


def main() -> int:
    contract = load_contract()
    total_added = 0
    for engine, caps in sorted(contract.items()):
        added, path = sync_engine(engine, caps)
        total_added += added
        if added:
            print(f"{engine}: added {added} capabilities to {path.relative_to(ROOT)}")
        else:
            print(f"{engine}: already in sync")
    print(f"total added: {total_added}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
