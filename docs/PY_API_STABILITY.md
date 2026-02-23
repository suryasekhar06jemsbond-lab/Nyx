# Python API Stability Policy

This policy applies to:

- `src/token_types.py`
- `src/lexer.py`
- `src/parser.py`
- `src/interpreter.py`
- `src/debugger.py`
- `src/ownership.py`
- `src/borrow_checker.py`
- `src/ast_nodes.py`

## Versioning

- Each module exposes `API_VERSION` in semver format.
- Patch (`x.y.Z`): internal fixes, no public API removal.
- Minor (`x.Y.z`): backward-compatible API additions.
- Major (`X.y.z`): removals/renames/breaking behavior changes.

## Public API Contract

- Public class methods listed in `tests/hardening/contracts/public_api_v1.json` are compatibility-protected.
- Removing or renaming those methods requires:
1. major version bump
2. migration notes
3. release note entry

## Native Dependency Rule

- Core Python modules above must remain stdlib-only plus internal `src.*` imports.
- Third-party runtime dependencies are not allowed for these modules.
- Enforced by `tests/hardening/test_native_stdlib_only.py`.

## CI Gates

- Contract gate: `tests/hardening/test_api_compat_snapshot.py`
- Hardening suite: `tests/hardening/run_hardening.py`
- Perf gate: `tests/hardening/run_perf_baseline.py`
