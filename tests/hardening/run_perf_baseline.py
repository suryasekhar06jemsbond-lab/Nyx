#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

print("[perf_baseline] Root: {}".format(ROOT))
print("[perf_baseline] sys.path updated")

try:
    from src.interpreter import Environment, Interpreter
    from src.lexer import Lexer
    from src.parser import Parser
    print("[perf_baseline] Imports successful")
except ImportError as e:
    print("[perf_baseline] ERROR: Import failed: {}".format(e))
    sys.exit(1)

BUDGET_FILE = ROOT / "tests" / "hardening" / "baselines" / "perf_budget.json"
REPORT_FILE = ROOT / "tests" / "checkup" / "python_hardening_perf_latest.json"


def _benchmark_lexer(iterations: int = 200) -> float:
    src = "let x = 1; let y = x + 2; if (y > 1) { y; }"
    t0 = time.perf_counter()
    token_count = 0
    for _ in range(iterations):
        token_count += len(list(Lexer(src).tokens()))
    dt = max(time.perf_counter() - t0, 1e-9)
    return token_count / dt


def _benchmark_parser(iterations: int = 150) -> float:
    src = "let x = 0; while (x < 10) { x = x + 1; } x;"
    t0 = time.perf_counter()
    node_count = 0
    for _ in range(iterations):
        p = Parser(Lexer(src))
        program = p.parse_program()
        node_count += len(program.statements)
    dt = max(time.perf_counter() - t0, 1e-9)
    return node_count / dt


def _benchmark_interpreter(iterations: int = 120) -> float:
    src = "let total = 0; for (v in [1,2,3,4,5]) { total = total + v; } total;"
    t0 = time.perf_counter()
    eval_count = 0
    for _ in range(iterations):
        p = Parser(Lexer(src))
        program = p.parse_program()
        Interpreter().eval(program, Environment())
        eval_count += 1
    dt = max(time.perf_counter() - t0, 1e-9)
    return eval_count / dt


def run() -> int:
    try:
        if not BUDGET_FILE.exists():
            print("[perf_baseline] ERROR: Budget file not found: {}".format(BUDGET_FILE))
            return 1
        
        budget = json.loads(BUDGET_FILE.read_text(encoding="utf-8"))
        print("[perf_baseline] Budget loaded: {}".format(budget))
        
        metrics = {
            "lexer_tokens_per_sec": _benchmark_lexer(),
            "parser_nodes_per_sec": _benchmark_parser(),
            "interpreter_evals_per_sec": _benchmark_interpreter(),
        }
        print("[perf_baseline] Metrics calculated: {}".format(metrics))
        
        result = {
            "budget": budget,
            "metrics": metrics,
            "pass": (
                metrics["lexer_tokens_per_sec"] >= budget["lexer_tokens_per_sec_min"]
                and metrics["parser_nodes_per_sec"] >= budget["parser_nodes_per_sec_min"]
                and metrics["interpreter_evals_per_sec"] >= budget["interpreter_evals_per_sec_min"]
            ),
        }
        REPORT_FILE.parent.mkdir(parents=True, exist_ok=True)
        REPORT_FILE.write_text(json.dumps(result, indent=2), encoding="utf-8")
        print(json.dumps(result, indent=2))
        return 0 if result["pass"] else 1
    except Exception as e:
        print("[perf_baseline] ERROR: {}".format(e))
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    raise SystemExit(run())
