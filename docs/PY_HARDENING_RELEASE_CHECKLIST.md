# Python Hardening Release Checklist

Scope: parser/lexer/interpreter/debugger/ownership/borrow/token registry + AST modules.

## Required Gates

1. `python tests/hardening/run_hardening.py`
2. `python tests/hardening/run_perf_baseline.py`
3. Existing platform production gates:
   - Linux: `./scripts/test_production.sh`
   - Windows: `./scripts/test_production.ps1 -VmCases 300`

## Artifact Requirements

- Store hardening output logs in CI.
- Store perf report from:
  - `tests/checkup/python_hardening_perf_latest.json`

## Release Notes Requirements

- Mention any `API_VERSION` changes in:
  - `src/token_types.py`
  - `src/lexer.py`
  - `src/parser.py`
  - `src/interpreter.py`
  - `src/debugger.py`
  - `src/ownership.py`
  - `src/borrow_checker.py`
  - `src/ast_nodes.py`

## Backward Compatibility Requirements

- If API snapshot fails, either:
1. restore compatibility, or
2. bump major API version and publish migration guidance.
