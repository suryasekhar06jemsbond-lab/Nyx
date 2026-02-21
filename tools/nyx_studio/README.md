# NYX Studio (Production Authoring Toolchain)

NYX Studio is the editor/tooling workspace for no-code and declarative game production.

## Modules

- Material Graph Editor (`nyrender`)
- Render Pipeline Graph Editor (`nyrender`)
- Constraint Graph Editor (`nyphysics`)
- World Zone + Economy Editor (`nyworld`)
- AI Intent + Memory Graph Editor (`nyai`)
- Replication/Interest Debugger (`nynet`)
- Acoustic Zone + Music State Editor (`nyaudio`)
- Intent Motion Editor (`nyanim`)
- Rule DSL Workbench (`nylogic`)

## Runtime Integration Contract

Every editor outputs normalized JSON and compile requests:

- graph assets -> compiler request -> runtime blob
- rule assets -> validator request -> runtime blob
- profile assets -> tier settings -> runtime update

All runtime updates are hot-reloadable through backend hooks.

## Suggested Layout

- `ui/` view and panel implementations
- `schemas/` graph/rule schema definitions
- `compiler/` IR conversion and validation
- `transport/` runtime RPC bridge
- `playtest/` live session sync and controls

## Minimum Features For Production

- autosave + journaling
- crash recovery
- undo/redo and operation logs
- diff-friendly asset format
- headless validation mode for CI

## Run The App

```bash
python3 tools/nyx_studio/studio_server.py --host 127.0.0.1 --port 4173
```

Open `http://127.0.0.1:4173`.

Saved assets are written under:

- `tools/nyx_studio/projects/default/material/`
- `tools/nyx_studio/projects/default/pipeline/`
- `tools/nyx_studio/projects/default/world/`
- `tools/nyx_studio/projects/default/logic/`
