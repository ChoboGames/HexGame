# AGENTS.md

Notes for OpenCode/agent sessions working in this repo.

## Project
- Godot 4.7 project, GDScript only, GL Compatibility renderer. Hex-grid, turn-based, 2-player strategy game.
- No README, tests, CI, linter, or formatter are configured. There is no `package.json`/lockfile — this is not a JS project.

## Run / verify
- Open the project in the **Godot 4.7 editor** and press F5. Main scene: `src/ui/main_menu.tscn`.
- No automated test/lint/typecheck exists. Verify behavior manually in the editor.
- If a Godot binary is on PATH, `godot --headless --check-only path/to/script.gd` is the closest script sanity check.

## Workflow
- Work on a feature branch, open a PR into `master` (default branch). Keep PRs scoped.

## Architecture
- Scene flow: `main_menu.tscn` → `game.tscn` (play) or `map_editor.tscn` (edit), switched with `get_tree().change_scene_to_file()`.
- Nodes do NOT persist across scene changes. Cross-scene state is passed via **static class vars**: `Game.selected_map_path` and `MapEditor.selected_map_path`, set by `main_menu.gd` before switching scenes. If you add cross-scene data, follow this pattern.
- Globally-registered `class_name` types (used without `preload`/`load`): `Game`, `MapEditor`, `MapSerializer`, `ShapeGenerator`, `GridOverlay`, `UnitStats`, `CameraController2D`.

## Hex grid
- Coordinates are axial-like `(i, j)`. Each Hex stores 6 neighbors: `up_left`, `up_center`, `up_right`, `down_left`, `down_center`, `down_right`.
- Neighbor connectivity is wired imperatively in two places — `Game.do_connections()` and `MapEditor.reconnect_all_neighbors()`. Changing neighbor semantics requires updating both.
- Hex↔world math lives canonically in `ShapeGenerator` (`hex_to_world`, `world_to_hex`, `hex_distance`). All geometry is derived from a single `ShapeGenerator.HEX_SIZE` constant (texture bounding box in pixels). `Game._ready()` calls `ShapeGenerator.hex_to_world()` — no duplication.

## Maps (JSON)
- Schema: `{ "name", "width", "height", "active_hexes": [[i,j], ...], "units": [{i,j,unit_type,player_index}, ...] }`.
- `MapSerializer.list_maps()` scans two directories: shipped read-only `res://maps/` (committed, e.g. `maps/default_map.json`) and runtime `user://maps/` (user-saved, not in repo). Saved maps always write to `user://`.

## Units
- Unit types: `king`, `archer`, `wolf`, `eagle` (flying), `soldier`. Stats are `UnitStats` Resource files in `src/units/resources/<unit_type>_stats.tres`, loaded by string path in `spawn_unit_at()` (both `game.gd` and `map_editor.gd`).
- Unit portrait icons resolve by name convention: `res://assets/units/<unit_type>.png` (see `UnitStats.get_icon_for_type()`). Missing PNG falls back to the unit letter.
- Adding a unit type requires: (1) a new `<type>_stats.tres`, (2) an 80×80 PNG at `assets/units/<type>.png`, (3) a placement button wired in `map_editor.tscn`, (4) a `_on_unit_<type>_pressed` handler in `map_editor.gd`, (5) if summonable by the King: node+handler in `game.tscn`/`game.gd` (`summonable_types`, `get_summon_button()`).
- The King can summon any non-king unit into adjacent valid hexes, paying `energy_cost` + `resource_cost` from the player's resources; summoned units spawn exhausted.
- 2 players, index 0/1. Player color is drawn by the unit's `Ring` sprite (`ring_mask.gdshader`); P0 blue, P1 red. Unit portraits are clipped to a circle by `icon_mask.gdshader` — no circle PNG asset.

## Conventions & gotchas
- **Deep node paths are load-bearing.** `@onready var x = $CanvasLayerUI/TopBar/...` and the `[connection]` lines in `.tscn` files depend on exact node names/paths. Renaming or moving UI nodes in `game.tscn` / `map_editor.tscn` silently breaks scripts — update scene + script together.
- **Spanish is intentional.** UI strings and many comments are in Spanish (e.g. "Terminar Turno"). Preserve Spanish for user-facing strings.
- **Generated files:** `*.import` and `*.uid` are Godot-generated; they are tracked in git but must never be hand-edited. `.godot/` is gitignored editor cache — never commit it.
- Indentation is tabs (Godot/GDScript default).
