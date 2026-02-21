# 02 Editor And Toolchain Delivery

## Objective

Ship a full production authoring environment so gameplay and content teams can build without imperative scripting.

## Product: NYX Studio

Starter package root:

- `tools/nyx_studio/`

### Required Editors

1. Material Graph Editor (`nyrender`)
2. Render Pipeline Graph Editor (`nyrender`)
3. Constraint Graph Editor (`nyphysics`)
4. World Rule + Zone + Economy Editor (`nyworld`)
5. AI Intent + Memory Graph Editor (`nyai`)
6. Replication + Interest Viewer (`nynet`)
7. Acoustic Zone + Music State Editor (`nyaudio`)
8. Intent Motion + Physics Adaptation Editor (`nyanim`)
9. Rule DSL + Validation Editor (`nylogic`)

## Data Contract

All editors save source-of-truth assets in text-based, diff-friendly format:

- `.nygraph.json` for node graphs
- `.nyrule.json` for declarative rules
- `.nyprofile.json` for tiering and runtime profiles

## Compiler Flow

Authoring -> Intermediate Representation -> Engine Runtime Blob

- Graph authoring emits normalized IR.
- Validation enforces schema and referential integrity.
- Compiler emits runtime blobs consumed by `native_*` backends.

## Cook/Build Pipeline

### Inputs

- raw assets (`assets/`)
- graph/rule assets
- engine profile configs

### Stages

1. asset import and normalization
2. graph/rule schema validation
3. dependency graph build
4. compile to runtime blobs
5. pack per platform
6. build manifest and checksums

### Outputs

- cooked content bundles
- debug symbol map
- dependency manifest
- incremental cache index

## Build Graph Requirements

- content-addressed cache keys
- deterministic output hashes
- incremental rebuild by dependency edge
- platform variant matrix support

## Editor Runtime Requirements

- autosave with journaling
- crash-safe recovery
- hot reload into running game session
- operation history and undo/redo
- collaborative lock model (multi-user)

## QA Requirements

- schema linting pre-commit
- broken reference detection in CI
- visual graph cycle detection
- deterministic re-cook verification

## Release Process

1. content branch freeze
2. cook dry-run
3. validation and perf gate
4. signed artifact publish
5. rollback package retention

## KPIs

- cold cook time
- incremental cook time
- editor crash-free session duration
- invalid asset rejection rate
- hot reload round-trip latency
