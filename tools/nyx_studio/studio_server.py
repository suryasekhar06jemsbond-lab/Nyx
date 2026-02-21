#!/usr/bin/env python3
"""NYX Studio local web app server."""

from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WEB_DIR = ROOT / "web"
PROJECT_DIR = ROOT / "projects" / "default"


def now_iso() -> str:
    return datetime.now(tz=timezone.utc).isoformat()


def stable_hash(payload: dict) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()[:16]


def compile_material(data: dict) -> dict:
    nodes = int(data.get("nodes", 0))
    layers = int(data.get("layers", 0))
    prompt = str(data.get("prompt", ""))
    out = {
        "kind": "material",
        "nodes": nodes,
        "layers": layers,
        "prompt": prompt,
        "hash": stable_hash({"nodes": nodes, "layers": layers, "prompt": prompt}),
        "compiled_at": now_iso(),
    }
    return out


def compile_pipeline(data: dict) -> dict:
    passes = int(data.get("passes", 0))
    edges = int(data.get("edges", 0))
    out = {
        "kind": "pipeline",
        "passes": passes,
        "edges": edges,
        "hash": stable_hash({"passes": passes, "edges": edges}),
        "compiled_at": now_iso(),
    }
    return out


def compile_world(data: dict) -> dict:
    rule_count = int(data.get("rule_count", 0))
    zone = str(data.get("zone", "default"))
    out = {
        "kind": "world",
        "rule_count": rule_count,
        "zone": zone,
        "hash": stable_hash({"rule_count": rule_count, "zone": zone}),
        "compiled_at": now_iso(),
    }
    return out


def compile_logic(data: dict) -> dict:
    rule_text = str(data.get("rule", ""))
    out = {
        "kind": "logic",
        "rule": rule_text,
        "valid": "when" in rule_text.lower() and "trigger" in rule_text.lower(),
        "hash": stable_hash({"rule": rule_text}),
        "compiled_at": now_iso(),
    }
    return out


class Handler(BaseHTTPRequestHandler):
    server_version = "NYXStudio/0.1"

    def _json(self, status: int, payload: dict) -> None:
        raw = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw.decode("utf-8"))

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/":
            target = WEB_DIR / "index.html"
            self._serve_file(target)
            return
        if self.path.startswith("/web/"):
            rel = self.path.removeprefix("/web/")
            target = (WEB_DIR / rel).resolve()
            if not str(target).startswith(str(WEB_DIR.resolve())):
                self.send_error(403)
                return
            self._serve_file(target)
            return
        if self.path == "/api/health":
            self._json(200, {"ok": True, "time": now_iso()})
            return
        self.send_error(404)

    def _serve_file(self, path: Path) -> None:
        if not path.exists() or not path.is_file():
            self.send_error(404)
            return
        data = path.read_bytes()
        mime, _ = mimetypes.guess_type(str(path))
        self.send_response(200)
        self.send_header("Content-Type", mime or "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self) -> None:  # noqa: N802
        try:
            body = self._read_json()
        except json.JSONDecodeError as exc:
            self._json(400, {"ok": False, "error": f"invalid json: {exc}"})
            return

        if self.path == "/api/compile/material":
            self._json(200, {"ok": True, "result": compile_material(body)})
            return
        if self.path == "/api/compile/pipeline":
            self._json(200, {"ok": True, "result": compile_pipeline(body)})
            return
        if self.path == "/api/compile/world":
            self._json(200, {"ok": True, "result": compile_world(body)})
            return
        if self.path == "/api/compile/logic":
            self._json(200, {"ok": True, "result": compile_logic(body)})
            return
        if self.path == "/api/save":
            kind = str(body.get("kind", "")).strip().lower()
            name = str(body.get("name", "")).strip()
            data = body.get("data")
            if kind not in {"material", "pipeline", "world", "logic"}:
                self._json(400, {"ok": False, "error": "kind must be material|pipeline|world|logic"})
                return
            if not name:
                self._json(400, {"ok": False, "error": "name required"})
                return
            safe = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in name)
            folder = PROJECT_DIR / kind
            folder.mkdir(parents=True, exist_ok=True)
            out = folder / f"{safe}.json"
            payload = {
                "kind": kind,
                "name": safe,
                "saved_at": now_iso(),
                "data": data,
            }
            out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
            self._json(200, {"ok": True, "path": str(out.relative_to(ROOT.parent.parent))})
            return

        self.send_error(404)


def main() -> int:
    parser = argparse.ArgumentParser(description="NYX Studio local server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=4173)
    args = parser.parse_args()

    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"NYX Studio running on http://{args.host}:{args.port}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
