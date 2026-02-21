#!/usr/bin/env python3
"""
NYX unified launcher.

Behavior:
- `.ny` files run via `nyx_runtime.py`
- non-`.ny` files and option-only calls run via native `nyx` runtime
- source files are resolved to absolute paths and executed with cwd = file directory
  so NYX apps can be launched from any terminal location
"""

from __future__ import annotations

import os
import pathlib
import subprocess
import sys
from typing import Iterable, Optional


VALUE_FLAGS = {
    "--max-alloc",
    "--max-steps",
    "--max-call-depth",
    "--step-count",
    "--break",
    "--debug-port",
    "--host",
    "--port",
}


def _launcher_root() -> pathlib.Path:
    script_path = pathlib.Path(__file__).resolve()
    if script_path.parent.name == "scripts":
        return script_path.parent.parent
    return script_path.parent


def _runtime_candidates(root: pathlib.Path) -> list[pathlib.Path]:
    if os.name == "nt":
        return [
            root / "nyx-native.exe",
            root / "nyx.exe",
            root / "nyx-native",
            root / "nyx",
        ]
    return [
        root / "nyx-native",
        root / "nyx",
        root / "nyx-native.exe",
        root / "nyx.exe",
    ]


def _is_placeholder_binary(path: pathlib.Path) -> bool:
    try:
        if not path.is_file():
            return False
        if path.stat().st_size > 64:
            return False
        blob = path.read_bytes().strip().lower()
        return blob in {b"not found", b""}
    except OSError:
        return False


def _pick_native_runtime(root: pathlib.Path) -> Optional[pathlib.Path]:
    env_native = os.environ.get("NYX_NATIVE")
    if env_native:
        candidate = pathlib.Path(env_native).expanduser()
        if candidate.exists() and not _is_placeholder_binary(candidate):
            return candidate.resolve()

    for candidate in _runtime_candidates(root):
        if candidate.exists() and not _is_placeholder_binary(candidate):
            return candidate.resolve()
    return None


def _pick_python_command() -> Optional[list[str]]:
    env_python = os.environ.get("NYX_PYTHON")
    if env_python:
        return [env_python]

    if sys.executable:
        return [sys.executable]

    if os.name == "nt":
        if _which("py"):
            return ["py", "-3"]
        if _which("python"):
            return ["python"]
        if _which("python3"):
            return ["python3"]
    else:
        if _which("python3"):
            return ["python3"]
        if _which("python"):
            return ["python"]

    return None


def _which(name: str) -> Optional[str]:
    path = os.environ.get("PATH", "")
    if not path:
        return None
    paths = path.split(os.pathsep)

    if os.name == "nt":
        pathext = os.environ.get("PATHEXT", ".COM;.EXE;.BAT;.CMD").split(";")
        probes = [name] if pathlib.Path(name).suffix else [name + ext for ext in pathext]
        for folder in paths:
            for probe in probes:
                candidate = pathlib.Path(folder) / probe
                if candidate.exists():
                    return str(candidate)
        return None

    for folder in paths:
        candidate = pathlib.Path(folder) / name
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def _first_source_index(args: list[str]) -> Optional[int]:
    i = 0
    while i < len(args):
        arg = args[i]

        if arg == "--":
            return i + 1 if i + 1 < len(args) else None

        if arg.startswith("-"):
            if "=" in arg:
                i += 1
                continue
            if arg in VALUE_FLAGS:
                i += 2
                continue
            i += 1
            continue

        return i

    return None


def _resolve_source(raw: str) -> pathlib.Path:
    path = pathlib.Path(raw).expanduser()
    if path.is_absolute():
        return path.resolve()
    return (pathlib.Path.cwd() / path).resolve()


def _run_command(cmd: Iterable[str], cwd: Optional[pathlib.Path] = None) -> int:
    proc = subprocess.run(list(cmd), cwd=str(cwd) if cwd else None)
    return int(proc.returncode)


def main() -> int:
    root = _launcher_root()
    args = sys.argv[1:]

    source_idx = _first_source_index(args)
    source_path: Optional[pathlib.Path] = None
    source_suffix = ""
    if source_idx is not None and source_idx < len(args):
        source_path = _resolve_source(args[source_idx])
        source_suffix = source_path.suffix.lower()

    if source_suffix == ".ny":
        runtime_py = root / "nyx_runtime.py"
        if not runtime_py.exists():
            print(f"Error: nyx_runtime.py not found at {runtime_py}", file=sys.stderr)
            return 1

        py_cmd = _pick_python_command()
        if not py_cmd:
            print("Error: Python 3 interpreter not found (set NYX_PYTHON).", file=sys.stderr)
            return 1

        prefix = args[:source_idx] if source_idx is not None else []
        if prefix:
            joined = " ".join(prefix)
            print(f"Warning: ignoring native-only options for .ny run: {joined}", file=sys.stderr)

        suffix_args = args[source_idx + 1 :] if source_idx is not None else []
        cmd = py_cmd + [str(runtime_py), str(source_path)] + suffix_args
        return _run_command(cmd, cwd=source_path.parent)

    native = _pick_native_runtime(root)
    if native is None:
        print(
            "Error: native NYX runtime not found. Expected nyx/nyx-native binary near launcher.",
            file=sys.stderr,
        )
        return 1

    dispatch_args = list(args)
    cwd = None
    if source_idx is not None and source_path is not None:
        dispatch_args[source_idx] = str(source_path)
        cwd = source_path.parent

    return _run_command([str(native), *dispatch_args], cwd=cwd)


if __name__ == "__main__":
    raise SystemExit(main())

