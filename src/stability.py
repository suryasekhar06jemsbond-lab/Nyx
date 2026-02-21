"""
Shared Nyx stability and compatibility configuration.

Goal:
- keep parser/runtime/compiler resilient as syntax evolves
- allow adding compatibility rules via config instead of core source edits
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import json
import re
from typing import Dict, List, Set, Tuple


@dataclass
class RuntimeRewrite:
    pattern: str
    replacement: str


@dataclass
class NyxStabilityConfig:
    noop_directives: Set[str] = field(default_factory=lambda: {"use", "import"})
    modifier_keywords: Set[str] = field(default_factory=lambda: {"pub"})
    auto_call_main: bool = True
    known_modules: Set[str] = field(default_factory=set)
    runtime_rewrites: List[RuntimeRewrite] = field(default_factory=lambda: [
        RuntimeRewrite(r"::", "."),
        RuntimeRewrite(r"\.starts_with\(", ".startswith("),
        RuntimeRewrite(r"\.toLower\(", ".lower("),
        RuntimeRewrite(r"\.toUpper\(", ".upper("),
    ])

    def compiled_rewrites(self) -> List[Tuple[re.Pattern, str]]:
        compiled: List[Tuple[re.Pattern, str]] = []
        for rewrite in self.runtime_rewrites:
            try:
                compiled.append((re.compile(rewrite.pattern), rewrite.replacement))
            except re.error:
                # Ignore malformed custom regex entries instead of breaking runtime.
                continue
        return compiled


def _workspace_root(start: Path | None = None) -> Path:
    if start is None:
        start = Path(__file__).resolve()
    # src/stability.py -> repo root is parent of src
    return start.parent.parent


def discover_engine_modules(engines_dir: Path) -> Set[str]:
    modules: Set[str] = set()
    if not engines_dir.exists():
        return modules

    # Directory names
    for child in engines_dir.iterdir():
        if child.is_dir():
            modules.add(child.name)

    # Manifest names (ny.pkg)
    for pkg in engines_dir.glob("*/ny.pkg"):
        try:
            text = pkg.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        m = re.search(r'name\s*:\s*"([^"]+)"', text)
        if m:
            modules.add(m.group(1))
    return modules


def _merge_list_of_strings(target: Set[str], value) -> None:
    if not isinstance(value, list):
        return
    for item in value:
        if isinstance(item, str) and item.strip():
            target.add(item.strip())


def load_stability_config(root: Path | None = None) -> NyxStabilityConfig:
    root = _workspace_root(root)
    cfg = NyxStabilityConfig()
    cfg.known_modules = discover_engine_modules(root / "engines")

    cfg_path = root / ".nyx" / "stability.json"
    if not cfg_path.exists():
        return cfg

    try:
        data = json.loads(cfg_path.read_text(encoding="utf-8"))
    except Exception:
        return cfg

    parser_cfg = data.get("parser", {})
    runtime_cfg = data.get("runtime", {})
    modules_cfg = data.get("modules", {})

    if isinstance(parser_cfg, dict):
        _merge_list_of_strings(cfg.noop_directives, parser_cfg.get("noop_directives"))
        _merge_list_of_strings(cfg.modifier_keywords, parser_cfg.get("modifier_keywords"))

    if isinstance(runtime_cfg, dict):
        auto_call_main = runtime_cfg.get("auto_call_main")
        if isinstance(auto_call_main, bool):
            cfg.auto_call_main = auto_call_main

        rewrites = runtime_cfg.get("rewrites")
        if isinstance(rewrites, list):
            parsed: List[RuntimeRewrite] = []
            for item in rewrites:
                if not isinstance(item, dict):
                    continue
                pattern = item.get("pattern")
                replacement = item.get("replacement")
                if isinstance(pattern, str) and isinstance(replacement, str):
                    parsed.append(RuntimeRewrite(pattern=pattern, replacement=replacement))
            if parsed:
                cfg.runtime_rewrites = parsed

    if isinstance(modules_cfg, dict):
        _merge_list_of_strings(cfg.known_modules, modules_cfg.get("extra"))

    return cfg
