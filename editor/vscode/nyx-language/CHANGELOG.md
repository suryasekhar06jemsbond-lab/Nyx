# Changelog

## v3.0.3 (3.0.3)

- Version bump to v3.0.3.
- Updated release artifacts for GitHub release.
- Cross-folder execution support for `.ny` files from any directory.

## v3.0.2 (3.0.2)

- Added unified launcher (`nyx_launcher.py`) for cross-folder NYX file execution.
- Updated `nyx.bat` and created `nyx.sh` to route `.ny` files through `nyx_runtime.py`.
- Native `.nx`/non-`.ny` files continue to use native runtime.
- Working directory set to script location for consistent project-relative paths.
- Regenerated VSIX artifacts for v3.0.2 release.

## v3.0.1 (3.0.1)

- Improved NYX file icon reliability for `.ny` and `.nx` via icon theme defaults (`workbench.iconTheme = nyx-file-icons`).
- Added explicit icon-theme language mapping for `nyx` language id.
- Updated install documentation with DNS fallback commands when `raw.githubusercontent.com` is unreachable.
- Synced `.vscode/launch.json` and `.vscode/tasks.json` updates from workspace.
- Regenerated v3.0.1 VSIX marketplace artifacts.

## v3.0.0 (3.0.0)

- Added NYX file icon support for `.ny` and `.nx` with explicit language icon metadata.
- Added bundled `NYX File Icons` theme (`icon-theme/nyx-icon-theme.json`) for reliable Explorer icon mapping.
- Added icon mapping for NYX project files (`nyx.mod`, `ny.pkg`, `nyproject.toml`).
- Updated README with expanded feature coverage and icon-theme enable steps.
- Synced repository `.vscode/launch.json` and `.vscode/tasks.json` updates from workspace.
- Regenerated VSIX artifacts for v3.0.0 release uploads.

## v2.2.2 (2.2.2)

- Added extension icon packaging fix for marketplace by shipping `assets/nyx-logo.png` and wiring package icon metadata.
- Expanded README with high-detail `Features` and `Details` sections for beginner-to-advanced workflows.
- Added NYX-only project examples in README (module, class/state, and NYX web starter).
- Synced workspace launch/task templates for the repository `.vscode` configuration.
- Regenerated v2.2.2 marketplace artifacts for VS Code Marketplace, Open VSX, and VS studio naming output.

## v2.2.1 (2.2.1)

- Added NYX syntax highlighting for `.ny` and `.nx`.
- Added starter snippets for function/class/module/control-flow.
- Added beginner-to-advanced authoring guide and publish workflow alignment.
