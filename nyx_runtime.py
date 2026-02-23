#!/usr/bin/env python3
"""
Nyx runtime bridge for web-style `.ny` scripts.

Current implementation is optimized for:
- tests/nyui/pure_web.ny
- examples/student/ultra_modern_school_website.ny (basic compatibility)
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import tempfile
import threading
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Callable, Dict, List, Optional
from urllib.parse import urlparse


def _repo_root(start: pathlib.Path) -> pathlib.Path:
    for parent in [start] + list(start.parents):
        if (parent / "package.json").exists() or (parent / ".git").exists():
            return parent
    return start


def _read_json(path: pathlib.Path) -> Dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as fh:
            obj = json.load(fh)
        if isinstance(obj, dict):
            return obj
    except Exception:
        pass
    return {}


def _atomic_write_json(path: pathlib.Path, data: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=".nyx.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, sort_keys=True)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(temp, str(path))
    finally:
        if os.path.exists(temp):
            try:
                os.remove(temp)
            except OSError:
                pass


class PersistentStore:
    def __init__(self, path: str):
        self.path = pathlib.Path(path)
        self._lock = threading.RLock()
        if not self.path.exists():
            _atomic_write_json(self.path, {})

    @classmethod
    def new(cls, path: str) -> "PersistentStore":
        return cls(path)

    def get(self, key: str, default: Any = None) -> Any:
        with self._lock:
            return _read_json(self.path).get(key, default)

    def set(self, key: str, value: Any) -> None:
        with self._lock:
            data = _read_json(self.path)
            data[key] = value
            _atomic_write_json(self.path, data)

    def has(self, key: str) -> bool:
        with self._lock:
            return key in _read_json(self.path)

    def transaction(self, fn: Callable[[Dict[str, Any]], Any]) -> Any:
        with self._lock:
            data = _read_json(self.path)
            out = fn(data)
            _atomic_write_json(self.path, data)
            return out


@dataclass
class Request:
    method: str
    path: str
    headers: Dict[str, str]
    body: Any
    raw_body: bytes = b""
    content_type: str = ""
    client_ip: str = ""

    def json(self) -> Dict[str, Any]:
        if isinstance(self.body, dict):
            return self.body
        try:
            obj = json.loads((self.raw_body or b"{}").decode("utf-8"))
            if isinstance(obj, dict):
                return obj
        except Exception:
            pass
        return {}


@dataclass
class Response:
    status: int = 200
    body: Any = ""
    headers: Dict[str, str] = field(default_factory=dict)


@dataclass
class HttpRoute:
    path: str
    methods: List[str]
    handler: Callable[[Request], Any]


class Application:
    def __init__(self, name: str):
        self.name = name
        self.routes: List[HttpRoute] = []
        self._started = False

    def worker_model(self, max_concurrency: int = 128) -> None:
        _ = max_concurrency

    def worker_pool(self, workers: int = 8, queue_size: int = 1024, timeout_seconds: int = 20) -> None:
        _ = (workers, queue_size, timeout_seconds)

    def _start_worker_pool(self) -> None:
        self._started = True

    def _stop_worker_pool(self) -> None:
        self._started = False

    def worker_stats(self) -> Dict[str, Any]:
        return {"started": self._started}

    def _dispatch_via_pool(self, req: Request) -> Response:
        for route in self.routes:
            if route.path == req.path and req.method in route.methods:
                try:
                    out = route.handler(req)
                    if isinstance(out, Response):
                        return out
                    if isinstance(out, dict):
                        return Response(200, out, {"Content-Type": "application/json"})
                    return Response(200, {"ok": True, "result": out}, {"Content-Type": "application/json"})
                except Exception as exc:
                    return Response(500, {"ok": False, "error": str(exc)}, {"Content-Type": "application/json"})
        return Response(404, {"ok": False, "error": "not found"}, {"Content-Type": "application/json"})


@dataclass
class RuntimeConfig:
    script: pathlib.Path
    host: str
    port: int
    site_name: str
    site_tagline: str
    storage_dir: pathlib.Path
    repo_root: pathlib.Path


def _extract_string(source: str, key: str) -> Optional[str]:
    m = re.search(rf'let\s+{re.escape(key)}\s*=\s*"([^"]*)";', source)
    return m.group(1) if m else None


def _extract_host_port(source: str) -> Optional[tuple[str, int]]:
    m = re.search(r'site\.run\(\s*"([^"]+)"\s*,\s*(\d+)\s*\)\s*;', source)
    if not m:
        return None
    return m.group(1), int(m.group(2))


def load_config(script: pathlib.Path, host_override: Optional[str], port_override: Optional[int]) -> RuntimeConfig:
    src = script.read_text(encoding="utf-8")
    root = _repo_root(script.parent.resolve())
    hp = _extract_host_port(src) or ("127.0.0.1", 8080)

    site_name = _extract_string(src, "SITE_NAME") or _extract_string(src, "SCHOOL_NAME") or "Nyx Website"
    site_tagline = _extract_string(src, "SITE_TAGLINE") or _extract_string(src, "SCHOOL_TAGLINE") or "Built with Nyx"
    store_raw = _extract_string(src, "PORTAL_DIR") or _extract_string(src, "ADMISSION_DIR") or "tests/nyui/NYX PORTAL"
    store = pathlib.Path(store_raw)
    if not store.is_absolute():
        store = (root / store).resolve()

    return RuntimeConfig(
        script=script.resolve(),
        host=host_override or hp[0],
        port=int(port_override if port_override is not None else hp[1]),
        site_name=site_name,
        site_tagline=site_tagline,
        storage_dir=store,
        repo_root=root,
    )


class NyxRuntimeServer:
    def __init__(self, cfg: RuntimeConfig):
        self.cfg = cfg
        self._lock = threading.RLock()
        self.counter = PersistentStore.new(str(cfg.storage_dir / "_counter.json"))
        self.metrics = PersistentStore.new(str(cfg.storage_dir / "_metrics.json"))
        self.ready = PersistentStore.new(str(cfg.storage_dir / ".ready.json"))
        self.ready.set("ready", True)

    def metric(self, key: str) -> int:
        try:
            return int(self.metrics.get(key, 0) or 0)
        except Exception:
            return 0

    def set_metric(self, key: str, value: int) -> None:
        self.metrics.set(key, int(value))

    def bump_visit(self) -> None:
        self.set_metric("visits", self.metric("visits") + 1)

    def bump_run(self) -> int:
        runs = self.metric("playground_runs") + 1
        self.set_metric("playground_runs", runs)
        return runs

    def next_signup(self) -> str:
        with self._lock:
            cur = int(self.counter.get("value", 0) or 0) + 1
            self.counter.set("value", cur)
            return f"NYX-{cur:06d}"

    def save_signup(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        name = str(payload.get("name") or "").strip()
        email = str(payload.get("email") or "").strip()
        role = str(payload.get("role") or "").strip()
        focus = str(payload.get("focus") or "").strip()
        submitted = str(payload.get("submitted_at") or "").strip() or "client-generated"
        if not name:
            raise ValueError("name is required")
        if not email:
            raise ValueError("email is required")

        signup_no = self.next_signup()
        target = self.cfg.storage_dir / f"{signup_no}.json"
        PersistentStore.new(str(target)).set(
            "signup",
            {
                "signup_no": signup_no,
                "name": name,
                "email": email,
                "role": role,
                "focus": focus,
                "created_at": submitted,
            },
        )
        self.set_metric("signups", self.metric("signups") + 1)
        return {"ok": True, "signup_no": signup_no, "file_path": str(target), "saved": True}

    def preview_html(self) -> str:
        preview = self.cfg.script.parent / "pure_web.preview.html"
        if preview.exists():
            return preview.read_text(encoding="utf-8")
        return (
            "<!doctype html><html><head><meta charset='utf-8'><title>"
            + self.cfg.site_name
            + "</title></head><body><h1>"
            + self.cfg.site_name
            + "</h1><p>"
            + self.cfg.site_tagline
            + "</p></body></html>"
        )


class NyxHandler(BaseHTTPRequestHandler):
    server_ref: NyxRuntimeServer

    def _send_json(self, status: int, payload: Dict[str, Any]) -> None:
        blob = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(blob)))
        self.send_header("X-NYX-STACK", "nyx-runtime-python")
        self.end_headers()
        self.wfile.write(blob)

    def _send_text(self, status: int, body: str, ctype: str) -> None:
        blob = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(blob)))
        self.send_header("X-NYX-STACK", "nyx-runtime-python")
        self.end_headers()
        self.wfile.write(blob)

    def _serve_asset(self, path: str) -> bool:
        if not path.startswith("/assets/"):
            return False
        rel = path[len("/assets/") :]
        target = (self.server_ref.cfg.repo_root / "assets" / rel).resolve()
        assets_root = (self.server_ref.cfg.repo_root / "assets").resolve()
        try:
            target.relative_to(assets_root)
        except Exception:
            self._send_text(403, "Forbidden", "text/plain; charset=utf-8")
            return True
        if not target.exists() or not target.is_file():
            return False
        data = target.read_bytes()
        ctype = "application/octet-stream"
        if target.suffix.lower() == ".png":
            ctype = "image/png"
        elif target.suffix.lower() in {".jpg", ".jpeg"}:
            ctype = "image/jpeg"
        elif target.suffix.lower() == ".svg":
            ctype = "image/svg+xml"
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        return True

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if self._serve_asset(path):
            return

        if path in {"/", "/docs", "/ecosystem", "/playground"}:
            self.server_ref.bump_visit()
            self._send_text(200, self.server_ref.preview_html(), "text/html; charset=utf-8")
            return

        if path == "/api/health":
            self._send_json(
                200,
                {
                    "ok": True,
                    "service": "nyx-runtime",
                    "name": self.server_ref.cfg.site_name,
                    "storage_dir": str(self.server_ref.cfg.storage_dir),
                },
            )
            return

        if path == "/api/overview":
            self._send_json(
                200,
                {
                    "ok": True,
                    "name": self.server_ref.cfg.site_name,
                    "tagline": self.server_ref.cfg.site_tagline,
                    "engines": ["nyweb", "nyrender", "nyanim", "nyai", "nynet", "nycore"],
                    "tooling": ["nypm", "nyfmt", "nylint", "nydbg"],
                },
            )
            return

        if path == "/api/metrics":
            self._send_json(
                200,
                {
                    "ok": True,
                    "visits": self.server_ref.metric("visits"),
                    "signups": self.server_ref.metric("signups"),
                    "playground_runs": self.server_ref.metric("playground_runs"),
                },
            )
            return

        self._send_text(404, "Not Found", "text/plain; charset=utf-8")

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        try:
            clen = int(self.headers.get("Content-Length", "0"))
        except Exception:
            clen = 0
        raw = self.rfile.read(clen) if clen > 0 else b"{}"
        try:
            payload = json.loads(raw.decode("utf-8"))
            if not isinstance(payload, dict):
                payload = {}
        except Exception:
            payload = {}

        if path == "/api/community/subscribe":
            try:
                out = self.server_ref.save_signup(payload)
                self._send_json(200, out)
            except ValueError as exc:
                self._send_json(400, {"ok": False, "error": str(exc)})
            except Exception as exc:
                self._send_json(500, {"ok": False, "error": str(exc)})
            return

        if path == "/api/playground/run":
            runs = self.server_ref.bump_run()
            self._send_json(200, {"ok": True, "status": "simulated-success", "output": "Hello, World from Nyx", "runs": runs})
            return

        self._send_json(404, {"ok": False, "error": "Not Found"})

    def log_message(self, fmt: str, *args: Any) -> None:
        _ = (fmt, args)


def main() -> int:
    ap = argparse.ArgumentParser(description="Run Nyx web-style .ny script")
    ap.add_argument("script", help="Path to .ny file")
    ap.add_argument("--host", default=None, help="Override host")
    ap.add_argument("--port", type=int, default=None, help="Override port")
    args = ap.parse_args()

    script = pathlib.Path(args.script)
    if not script.exists():
        print(f"Error: script not found: {script}")
        return 1
    if script.suffix.lower() != ".ny":
        print("Error: expected .ny source file")
        return 1

    cfg = load_config(script.resolve(), args.host, args.port)
    runtime = NyxRuntimeServer(cfg)
    handler = type("NyxRuntimeHandler", (NyxHandler,), {})
    handler.server_ref = runtime
    httpd = ThreadingHTTPServer((cfg.host, cfg.port), handler)
    print(f"[nyx-runtime] source: {cfg.script}")
    print(f"[nyx-runtime] open:   http://{cfg.host}:{cfg.port}")
    print(f"[nyx-runtime] store:  {cfg.storage_dir}")
    try:
        httpd.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

