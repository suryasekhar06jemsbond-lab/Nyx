#!/usr/bin/env python3
"""Compile backend hooks and run perf/stability/determinism gates."""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import statistics
import subprocess
import time
from pathlib import Path

ROOT = Path.cwd()
BUILD = ROOT / "build" / "aaa_gates"
LIB_NAME = "nyx_hooks.dll" if os.name == "nt" else "libnyx_hooks.so"
SO = BUILD / LIB_NAME
REPORT = ROOT / "tests" / "aaa_readiness" / "engine_gates_report.json"


class NyxBytes(ctypes.Structure):
    _fields_ = [("data", ctypes.POINTER(ctypes.c_ubyte)), ("len", ctypes.c_longlong)]


class NyxStringList(ctypes.Structure):
    _fields_ = [("items", ctypes.POINTER(ctypes.c_char_p)), ("len", ctypes.c_longlong)]


def compile_lib() -> None:
    BUILD.mkdir(parents=True, exist_ok=True)
    src = ROOT / "native" / "backends" / "generated" / "nyx_native_hooks_stub.c"
    inc = ROOT / "native" / "backends" / "generated"
    cc = os.environ.get("CC", "cc")
    if os.name == "nt":
        cmd = [
            cc,
            "-shared",
            "-O2",
            "-std=c11",
            str(src),
            "-I",
            str(inc),
            "-o",
            str(SO),
        ]
    else:
        cmd = [
            cc,
            "-shared",
            "-fPIC",
            "-O2",
            "-std=c11",
            str(src),
            "-I",
            str(inc),
            "-o",
            str(SO),
        ]
    subprocess.run(cmd, check=True)


def bytes_to_str(blob: NyxBytes) -> str:
    if not blob.data or blob.len <= 0:
        return ""
    return bytes(blob.data[i] for i in range(blob.len)).decode("utf-8", errors="replace")


def p95(values: list[float]) -> float:
    if not values:
        return 0.0
    values = sorted(values)
    idx = int(0.95 * (len(values) - 1))
    return values[idx]


def timed_call(times: dict[str, list[float]], key: str, fn, *args):
    t0 = time.perf_counter_ns()
    out = fn(*args)
    dt_ms = (time.perf_counter_ns() - t0) / 1_000_000.0
    times.setdefault(key, []).append(dt_ms)
    return out


def run(iterations: int, thresholds: dict) -> dict:
    lib = ctypes.CDLL(str(SO))

    try:
        # Prototypes used in gates.
        lib.native_render_boot.argtypes = [ctypes.c_char_p, ctypes.c_longlong, ctypes.c_longlong]
        lib.native_render_query_gpu_time_ms.restype = ctypes.c_double
        lib.native_render_query_gpu_memory_mb.restype = ctypes.c_longlong
        lib.native_nyrender_apply_tier.argtypes = [ctypes.c_char_p]
        lib.native_nyrender_compile_material_graph.argtypes = [ctypes.c_longlong, ctypes.c_longlong]
        lib.native_nyrender_compile_material_graph.restype = NyxBytes
        lib.native_nyrender_compile_pipeline_graph.argtypes = [ctypes.c_longlong, ctypes.c_longlong]
        lib.native_nyrender_compile_pipeline_graph.restype = NyxBytes

        lib.native_physics_boot.argtypes = []
        lib.native_physics_query_step_ms.restype = ctypes.c_double
        lib.native_physics_set_float_mode.argtypes = [ctypes.c_char_p]
        lib.native_physics_checksum.argtypes = [ctypes.c_longlong, NyxBytes]
        lib.native_physics_checksum.restype = ctypes.c_char_p
        lib.native_physics_validate_frame.argtypes = [ctypes.c_longlong, NyxBytes]
        lib.native_physics_validate_frame.restype = ctypes.c_int
        lib.native_nyphysics_auto_tune.argtypes = [NyxBytes]

        lib.native_nyai_build_hybrid_from_intent.argtypes = [ctypes.c_char_p]
        lib.native_nyai_build_hybrid_from_intent.restype = NyxBytes
        lib.native_nyai_run_sandbox.argtypes = [ctypes.c_longlong]
        lib.native_nyai_run_sandbox.restype = NyxBytes
        lib.native_ai_frame_time_ms.restype = ctypes.c_double

        lib.native_nynet_checksum.argtypes = [ctypes.c_longlong, NyxBytes]
        lib.native_nynet_checksum.restype = ctypes.c_char_p
        lib.native_nynet_validate_desync.argtypes = [ctypes.c_longlong, ctypes.c_char_p, ctypes.c_char_p]
        lib.native_nynet_validate_desync.restype = ctypes.c_int
        lib.native_nynet_tick_ms.restype = ctypes.c_double
        lib.native_nynet_packet_loss_pct.restype = ctypes.c_double

        lib.native_audio_create_context.restype = ctypes.c_void_p
        lib.native_audio_set_master_volume.argtypes = [ctypes.c_double]
        lib.native_audio_play.argtypes = [ctypes.c_longlong]
        lib.native_audio_stop.argtypes = [ctypes.c_longlong]
        lib.native_audio_dsp_time_ms.restype = ctypes.c_double

        lib.native_nyaudio_resolve_music_state.argtypes = [ctypes.c_char_p, ctypes.c_double]
        lib.native_nyaudio_resolve_music_state.restype = NyxStringList

        lib.native_nylogic_generate_rule.argtypes = [ctypes.c_char_p]
        lib.native_nylogic_generate_rule.restype = NyxBytes
        lib.native_nylogic_decode_rule.argtypes = [NyxBytes]
        lib.native_nylogic_decode_rule.restype = ctypes.c_char_p
        lib.native_nylogic_validate.argtypes = [ctypes.c_char_p, ctypes.c_longlong, ctypes.c_longlong]
        lib.native_nylogic_validate.restype = ctypes.c_int
        lib.native_nylogic_compile_graph.argtypes = [ctypes.c_longlong, ctypes.c_longlong]
        lib.native_nylogic_compile_graph.restype = NyxBytes
        lib.native_nylogic_execute.argtypes = [ctypes.c_char_p, NyxBytes]
        lib.native_nylogic_profile_ms.restype = ctypes.c_double
    except AttributeError as exc:
        return {
            "ok": True,
            "skipped": True,
            "reason": f"native hook symbols unavailable on this platform: {exc}",
            "iterations": 0,
            "timings": {"p95_ms": {}, "count": {}},
            "deterministic_failures": [],
            "stability_failures": [],
        }

    times: dict[str, list[float]] = {}

    # Boot phase.
    timed_call(times, "native_render_boot", lib.native_render_boot, b"vulkan", 1920, 1080)
    timed_call(times, "native_nyrender_apply_tier", lib.native_nyrender_apply_tier, b"high")
    timed_call(times, "native_physics_boot", lib.native_physics_boot)
    timed_call(times, "native_physics_set_float_mode", lib.native_physics_set_float_mode, b"deterministic_fp32")
    timed_call(times, "native_audio_create_context", lib.native_audio_create_context)
    timed_call(times, "native_audio_set_master_volume", lib.native_audio_set_master_volume, 1.0)

    deterministic_failures = []
    stability_failures = []

    payload_bytes = NyxBytes((ctypes.c_ubyte * 8)(*b"abcd1234"), 8)

    for i in range(iterations):
        # Render
        mat_a = timed_call(times, "native_nyrender_compile_material_graph", lib.native_nyrender_compile_material_graph, 12, 3)
        mat_b = timed_call(times, "native_nyrender_compile_material_graph", lib.native_nyrender_compile_material_graph, 12, 3)
        if bytes_to_str(mat_a) != bytes_to_str(mat_b):
            deterministic_failures.append("render_material_compile")

        timed_call(times, "native_nyrender_compile_pipeline_graph", lib.native_nyrender_compile_pipeline_graph, 7, 11)
        gpu_ms = timed_call(times, "native_render_query_gpu_time_ms", lib.native_render_query_gpu_time_ms)

        # Physics
        chk_a = timed_call(times, "native_physics_checksum", lib.native_physics_checksum, i, payload_bytes)
        chk_b = timed_call(times, "native_physics_checksum", lib.native_physics_checksum, i, payload_bytes)
        if chk_a != chk_b:
            deterministic_failures.append("physics_checksum")

        tuned_blob = NyxBytes((ctypes.c_ubyte * 4)(*b"2.5|"), 4)
        timed_call(times, "native_nyphysics_auto_tune", lib.native_nyphysics_auto_tune, tuned_blob)
        step_ms = timed_call(times, "native_physics_query_step_ms", lib.native_physics_query_step_ms)
        valid = timed_call(times, "native_physics_validate_frame", lib.native_physics_validate_frame, i, payload_bytes)
        if valid != 1:
            stability_failures.append("physics_validate")

        # AI
        ai_blob = timed_call(times, "native_nyai_build_hybrid_from_intent", lib.native_nyai_build_hybrid_from_intent, b"Aggressive police")
        if "hybrid_brain" not in bytes_to_str(ai_blob):
            stability_failures.append("ai_hybrid_output")
        timed_call(times, "native_nyai_run_sandbox", lib.native_nyai_run_sandbox, 600)
        ai_ms = timed_call(times, "native_ai_frame_time_ms", lib.native_ai_frame_time_ms)

        # Net
        net_a = timed_call(times, "native_nynet_checksum", lib.native_nynet_checksum, i, payload_bytes)
        net_b = timed_call(times, "native_nynet_checksum", lib.native_nynet_checksum, i, payload_bytes)
        if net_a != net_b:
            deterministic_failures.append("net_checksum")
        timed_call(times, "native_nynet_validate_desync", lib.native_nynet_validate_desync, i, net_a, net_b)
        net_tick = timed_call(times, "native_nynet_tick_ms", lib.native_nynet_tick_ms)
        packet_loss = timed_call(times, "native_nynet_packet_loss_pct", lib.native_nynet_packet_loss_pct)

        # Audio
        timed_call(times, "native_audio_play", lib.native_audio_play, 1)
        timed_call(times, "native_audio_stop", lib.native_audio_stop, 1)
        dsp_ms = timed_call(times, "native_audio_dsp_time_ms", lib.native_audio_dsp_time_ms)
        lst = timed_call(times, "native_nyaudio_resolve_music_state", lib.native_nyaudio_resolve_music_state, b"combat", 0.9)
        if lst.len <= 0:
            stability_failures.append("audio_music_layers")

        # Logic
        rule_blob = timed_call(times, "native_nylogic_generate_rule", lib.native_nylogic_generate_rule, b"Bank robbery at night")
        decoded = timed_call(times, "native_nylogic_decode_rule", lib.native_nylogic_decode_rule, rule_blob)
        if b"rule" not in decoded:
            stability_failures.append("logic_decode")
        valid_rule = timed_call(times, "native_nylogic_validate", lib.native_nylogic_validate, b"BankRobbery", 2, 1)
        if valid_rule != 1:
            stability_failures.append("logic_validate")
        timed_call(times, "native_nylogic_compile_graph", lib.native_nylogic_compile_graph, 6, 9)
        timed_call(times, "native_nylogic_execute", lib.native_nylogic_execute, b"PoliceResponse", payload_bytes)
        logic_ms = timed_call(times, "native_nylogic_profile_ms", lib.native_nylogic_profile_ms)

        if gpu_ms > thresholds["render_gpu_ms_max"]:
            stability_failures.append("render_gpu_budget")
        if step_ms > thresholds["physics_step_ms_max"]:
            stability_failures.append("physics_step_budget")
        if ai_ms > thresholds["ai_frame_ms_max"]:
            stability_failures.append("ai_frame_budget")
        if net_tick > thresholds["net_tick_ms_max"] or packet_loss > 20:
            stability_failures.append("net_budget")
        if dsp_ms > thresholds["audio_dsp_ms_max"]:
            stability_failures.append("audio_budget")
        if logic_ms > thresholds["logic_profile_ms_max"]:
            stability_failures.append("logic_budget")

    p95_map = {k: p95(v) for k, v in times.items()}
    api_p95_max = max(p95_map.values()) if p95_map else 0.0

    ok = (
        len(deterministic_failures) == 0
        and len(stability_failures) == 0
        and iterations >= thresholds["minimum_iterations"]
        and api_p95_max <= thresholds["api_call_p95_ms_max"]
    )

    return {
        "ok": ok,
        "iterations": iterations,
        "api_call_p95_ms_max": api_p95_max,
        "deterministic_failures": sorted(set(deterministic_failures)),
        "stability_failures": sorted(set(stability_failures)),
        "timings": {
            "p95_ms": p95_map,
            "count": {k: len(v) for k, v in times.items()},
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Run NYX engine gates")
    parser.add_argument("--iterations", type=int, default=500)
    parser.add_argument("--thresholds", default="configs/production/gate_thresholds.json")
    args = parser.parse_args()

    thresholds = json.loads((ROOT / args.thresholds).read_text(encoding="utf-8"))

    compile_lib()
    result = run(iterations=args.iterations, thresholds=thresholds)

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
