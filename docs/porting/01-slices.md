---
name: Porting order — slices
description: End-to-end slices of model + commands, ordered by priority
---

# Porting order — slices

The work is sliced by feature, not by layer. Each slice ports just enough of the model + command code to make one user-visible capability run end-to-end through Rust. Each slice is one (or a few related) review item.

Why slices, not phases:
- Porting all of "model" before any commands is a huge dead-code investment.
- A single command can't be meaningfully ported without its manager.
- Slicing gives reviewable, engine-testable progress every iteration.

Each slice closes when:
- Its commands deserialize + execute through Rust without errors.
- Its dispatch is flipped to Rust-only (entry added to `nativeCommandsOnly` in [scen_edit/command/command_manager.lua](../../scen_edit/command/command_manager.lua)).
- Integration tests boot SBC, fire the command, and assert observable state changed.

Lua side stays running in parallel until the flip lands.

## Order

Slice 0 first (control-plane infrastructure — every feature slice depends on it).
Then feature slices ordered by engine-testing value and by what's actually
unblocked. Map settings come early (general map config, distinct from
project/scenario-info). Triggers + variables come last. Widget commands are
spread across the slices they belong to, not deferred as a catch-all.

| # | Slice | Status |
|--:|-------|--------|
| 0 | [Command infrastructure](#0-command-infrastructure) — trait + dispatch + undo/redo + compound + bridge + widget-notify | done (stable) |
| 1 | [Terrain](#1-terrain) — shape / level / smooth / metal brushes | done (stable; flipped to Rust-only; heightmap recalc fixed via `set_height_map_func`) |
| 2 | [Heightmap](#2-heightmap) — load + save + import / export (async IO) | done (stable; native IO seam, 16-bit PNG, raw-f32 save/load by path, import undoable) |
| 3 | [Map settings](#3-map-settings) — sun / atmosphere / water / map-rendering | review (in stable; all setters Rust-only with `Gfx`-snapshot undo) |
| 4 | [Textures](#4-textures) — diffuse / shading / terrain texture / cache + grass + DNTS | review (in stable; Rust owns paint + cache + stroke close + undo/redo) |
| 5 | [Objects](#5-objects) — units & features add / remove / set / move (needs s11n) | review (in stable) |
| 6 | [Areas](#6-areas) | wip (not in stable) |
| 7 | [Teams & diplomacy](#7-teams--diplomacy) | review (in stable) |
| 8 | [Project lifecycle](#8-project-lifecycle) — save / load / export / sync / start / stop + scenario-info | wip — core (not in stable) |
| 9 | [Triggers + Variables](#9-triggers--variables) — depends on areas, teams | wip (not in stable) |

Notes from review:
- **Map settings** (sun/lighting/atmosphere/water/map-rendering) are general map
  config and should land early — they're fundamentally different from scenario
  *info* (project metadata), which goes with project lifecycle.
- **Triggers and variables** are bookkeeping; do them together, last.
- **Widget commands** aren't a catch-all "stays Lua" bucket — each belongs to its
  feature slice (e.g. `widget_terrain_change_texture` → textures). The genuinely
  widget-only ones (display text, follow unit) are called out per slice.

---

## 0. Command infrastructure

The control plane. Every other slice plugs into this. Has to land in stable before any feature slice can be reviewed there.

**Status:** in stable.

How the command system works (states, native bridge, dispatch, undo/redo,
intents) is described in [docs/design/command-system.md](../design/command-system.md).
This slice delivered it.

**Rust files**: [commands_api.rs](../../native/src/sbc/commands_api.rs) (public
surface) + [command_system/](../../native/src/sbc/command_system/) (`command.rs`,
`context.rs`, `command_manager.rs`, `registry.rs`, `model.rs`, and a `commands/`
subfolder with the four control commands). Transport (`{tag, data}` decode) lives
at the `SBC` boundary in [sbc.rs](../../native/src/sbc/sbc.rs).

Tree-layout conventions (feature = directory, thin `mod.rs`, etc.) are in
[conventions.md](conventions.md#code-structure). `command_system` is
domain-agnostic: feature models (e.g. terrain's `TerrainManager`) self-register
via an `inventory` `ModelFactory` and `Context` reaches them type-erased through
`ctx.model::<T>()` — see [model.rs](../../native/src/sbc/command_system/model.rs).

**Lua files**:
- [scen_edit/command/command.lua](../../scen_edit/command/command.lua) — base class
- [scen_edit/command/command_manager.lua](../../scen_edit/command/command_manager.lua) — bridge (`Spring.InvokeNativeModule` call + `nativeCommandsOnly` allowlist) and dispatch on the Lua side
- [scen_edit/command/compound_command.lua](../../scen_edit/command/compound_command.lua) — base for grouped commands

The bridge sends every command to Rust via `Spring.InvokeNativeModule(json.encode(msg:serialize()))`. Lua execution **also** runs (parallel) unless the class name appears in `nativeCommandsOnly`. Slice 0 leaves that allowlist empty — feature slices populate it as they land.

During the parallel period Lua still owns undo/redo bookkeeping + widget notify
(`nativeCommandsOnly` only suppresses Lua's `cmd:execute()`). Moving the undo
stack itself to Rust — `__cmd_id`, widget-notify via `lua_bridge`, command
`display()` — lands with the first slice that needs Rust-owned undo.

---

## 1. Terrain

Brush-based heightmap and metal-map editing. Engine-side via `Spring.SetHeightMap` / `Spring.SetMetalAmount` / `Spring.AddHeightMap`, all bound natively.

**Status:** done (stable) — four brush commands + brush-settings, flipped to
Rust-only. Also landed shared infra: the IO-worker shell, the in-engine test
harness, and the Lua `poll_io` driver.

The three heightmap brushes wrap their writes in `TerrainControl::set_height_map_func`
so the engine recalcs (without it, heights change in data but the terrain doesn't
move) — see `SBC_PORT_MISSING_BINDINGS.md`. Metal needs no recalc.

**Model:**
- [scen_edit/model/terrain_manager.lua](../../scen_edit/model/terrain_manager.lua) — brush state, listeners, generated metadata
- [scen_edit/model/heightmap.lua](../../scen_edit/model/heightmap.lua)
- [scen_edit/model/rendering/texture_undo_stack.lua](../../scen_edit/model/rendering/texture_undo_stack.lua) (also used by textures)

**Commands (Lua source → Rust):**
- [abstract_terrain_modify_command.lua](../../scen_edit/command/abstract_terrain_modify_command.lua) — shared base; its brush-stamp logic became [brush_modify.rs](../../native/src/sbc/heightmap/model/brush_modify.rs) (composition via closures, not inheritance) + [brush_filter_generator.rs](../../native/src/sbc/heightmap/model/brush_filter_generator.rs)
- [terrain_shape_modify_command.lua](../../scen_edit/command/terrain_shape_modify_command.lua) → [terrain_shape_modify_command.rs](../../native/src/sbc/heightmap/commands/terrain_shape_modify_command.rs)
- [terrain_level_command.lua](../../scen_edit/command/terrain_level_command.lua) → [terrain_level_command.rs](../../native/src/sbc/heightmap/commands/terrain_level_command.rs)
- [terrain_smooth_command.lua](../../scen_edit/command/terrain_smooth_command.lua) → [terrain_smooth_command.rs](../../native/src/sbc/heightmap/commands/terrain_smooth_command.rs)
- [terrain_metal_command.lua](../../scen_edit/command/terrain_metal_command.lua) → [terrain_metal_command.rs](../../native/src/sbc/heightmap/commands/terrain_metal_command.rs)
- [set_heightmap_brush_command.lua](../../scen_edit/command/set_heightmap_brush_command.lua) → [set_heightmap_brush_command.rs](../../native/src/sbc/heightmap/commands/set_heightmap_brush_command.rs) (registers the greyscale brush shape in [terrain_manager.rs](../../native/src/sbc/heightmap/model/terrain_manager.rs); **not** flipped to Rust-only — Lua still needs the shape for its own preview)

---

## 2. Heightmap

Whole-map load + 16-bit-greyscale image import/export, all Rust-only. Load reads
the `.data` file (LE `f32`) by **path** — Lua passes the path, not the bytes, so
the heightmap never crosses the bridge. Import/export decode/encode on the
background IO worker (the first concrete `IoJob`/`IoOutcome` types, via the
`image` crate), replacing the spring-launcher round-trip; the engine thread
applies/reads heights. See [docs/design/async-io.md](../design/async-io.md).

**Model:**
- [scen_edit/model/heightmap.lua](../../scen_edit/model/heightmap.lua) (shared with slice 1)

**Commands** (all → Rust-only):
- [load_map_command.lua](../../scen_edit/command/load_map_command.lua) — passes the heightmap file path; Rust reads the LE-`f32` `.data` and applies. (Driven by project load — [load_project_command_widget.lua](../../scen_edit/command/project/load_project_command_widget.lua) now passes the path.)
- [import_heightmap_command.lua](../../scen_edit/command/import_heightmap_command.lua) — image decode in Rust; was launcher `ImportSBHeightmap`
- [export_heightmap_command.lua](../../scen_edit/command/textures/export_heightmap_command.lua) — read live heights via `get_ground_height`, encode 16-bit PNG; was launcher `ConvertSBHeightmap`

---

## 3. Map settings

General map rendering config: sun lighting, atmosphere, water, map-rendering
params. These are **map-wide config**, distinct from scenario *info* (project
metadata, which is in slice 8). Should land early.

**Status:** review (in stable) — all six setters Rust-only, partial-opts, with
`Gfx`-getter-snapshot undo (map-rendering & global-LOS have no undo, matching
their Lua). Dispatched to the gadget like every other command (`commandManager:
execute(cmd)`); native does the `Gfx`/`unsynced_ctrl` work from the gadget-invoked
main thread, where `Gfx` is valid — same as the textures slice — so the Lua
`_execute_unsynced` flag is bypassed for these (native-only) and no bridge change
is needed. Water re-selects the current water mode after applying so the renderer
reloads. Lua command files unchanged — only the `nativeCommandsOnly` flip.

**Commands:**
- [set_sun_lighting_command.lua](../../scen_edit/command/set_sun_lighting_command.lua)
- [set_sun_parameters_command.lua](../../scen_edit/command/set_sun_parameters_command.lua)
- [set_atmosphere_command.lua](../../scen_edit/command/set_atmosphere_command.lua)
- [set_water_params_command.lua](../../scen_edit/command/set_water_params_command.lua)
- [set_map_rendering_params_command.lua](../../scen_edit/command/set_map_rendering_params_command.lua)
- [set_global_los_command.lua](../../scen_edit/command/set_global_los_command.lua)
- [merge_command.lua](../../scen_edit/command/merge_command.lua) — used as the `mergeCommand` for sun/atmosphere/water; port here where its inner commands exist

---

## 4. Textures

Map texturing (terrain texture, diffuse, shading, grass, DNTS), via native `Gfx`
(texture creation, render-to-texture, readback, image save, blits, shaders).

**Status:** in stable for review. Rust owns the paint workflow — paint, cache,
stroke close, undo/redo (`nativeCommandsOnly`); `Gfx` render-to-texture runs
directly from the command path (no `DrawScreen` deferral). Optional shading
textures created by the editor are mirrored lazily before painting. Feature lives
under `native/src/sbc/textures/{commands,model}`.

**Deferred:** load / import / export commands (`LoadTextureCommand`,
`ImportDiffuseCommand`, `LoadGrassMapCommand`, `LoadMetalMapCommand`,
`ImportShadingImageCommand`, `ExportDiffuseCommand`,
`ExportShadingTexturesCommand`, `ExportGrassCommand`, `ExportMetalCommand`).
These are project save/load IO and belong with the project-load pipeline.

**Model:**
- [scen_edit/model/texture_manager.lua](../../scen_edit/model/texture_manager.lua)
- [scen_edit/model/rendering/active_drawing.lua](../../scen_edit/model/rendering/active_drawing.lua)
- [scen_edit/model/rendering/texture_undo_stack.lua](../../scen_edit/model/rendering/texture_undo_stack.lua) (shared with slice 1)
- [scen_edit/model/assets_manager.lua](../../scen_edit/model/assets_manager.lua)
- [scen_edit/model/brush_manager.lua](../../scen_edit/model/brush_manager.lua)

**Commands:**
- [terrain_change_texture_command.lua](../../scen_edit/command/terrain_change_texture_command.lua) — Rust-owned (`nativeCommandsOnly`)
- [widget_terrain_change_texture_command.lua](../../scen_edit/command/widget_terrain_change_texture_command.lua) — legacy fallback; dormant for Rust-owned texture strokes
- [terrain_grass_command.lua](../../scen_edit/command/terrain_grass_command.lua)
- [cache_texture_command.lua](../../scen_edit/command/cache_texture_command.lua) — Rust-owned (`nativeCommandsOnly`)
- [import_diffuse_command.lua](../../scen_edit/command/import_diffuse_command.lua) — deferred to project-load IO
- [import_shading_image_command.lua](../../scen_edit/command/import_shading_image_command.lua) — deferred to project-load IO
- [load_texture_command.lua](../../scen_edit/command/load_texture_command.lua) — deferred to project-load IO
- [load_grass_map_command.lua](../../scen_edit/command/load_grass_map_command.lua)
- [load_metal_map_command.lua](../../scen_edit/command/load_metal_map_command.lua)
- [export_diffuse_command.lua](../../scen_edit/command/textures/export_diffuse_command.lua) — deferred to project-save IO
- [export_shading_textures_command.lua](../../scen_edit/command/textures/export_shading_textures_command.lua) — deferred to project-save IO
- [export_grass_command.lua](../../scen_edit/command/textures/export_grass_command.lua) — deferred to project-save IO
- [export_metal_command.lua](../../scen_edit/command/textures/export_metal_command.lua) — deferred to project-save IO

---

## 5. Objects

Units and features — add / remove / set / move. **Large**: depends on the
`s11n` reflective serialization library + the object bridges + a modelID↔springID
mapping. Core engine ops (`create_unit` / `destroy_unit` / `create_feature` /
`destroy_feature` / `transfer_unit`) are bound; the bulk of the work is porting
s11n's per-field get/set.

**Model:**
- [scen_edit/model/object/object_bridge.lua](../../scen_edit/model/object/object_bridge.lua)
- [scen_edit/model/object/unit_bridge.lua](../../scen_edit/model/object/unit_bridge.lua)
- [scen_edit/model/object/feature_bridge.lua](../../scen_edit/model/object/feature_bridge.lua)
- [scen_edit/model/object/position_bridge.lua](../../scen_edit/model/object/position_bridge.lua)
- [scen_edit/model/runtime_model/runtime_model.lua](../../scen_edit/model/runtime_model/runtime_model.lua)
- [scen_edit/model/runtime_model/field_resolver.lua](../../scen_edit/model/runtime_model/field_resolver.lua)
- [scen_edit/model/extensions_manager.lua](../../scen_edit/model/extensions_manager.lua)
- `libs_sb/s11n/` — the serialization library (large)

**Commands:**
- [add_object_command.lua](../../scen_edit/command/add_object_command.lua)
- [remove_object_command.lua](../../scen_edit/command/remove_object_command.lua)
- [set_object_command.lua](../../scen_edit/command/set_object_command.lua)
- [set_object_param_command.lua](../../scen_edit/command/set_object_param_command.lua)
- [load_model_command.lua](../../scen_edit/command/load_model_command.lua)
- [object_sync.lua](../../scen_edit/command/sync/object_sync.lua)
- [widget_follow_unit_command.lua](../../scen_edit/command/widget_follow_unit_command.lua) — genuinely widget-only (camera follow); stays Lua

---

## 6. Areas

Map regions used by triggers and editor tools.

**Model:**
- [scen_edit/model/area_manager.lua](../../scen_edit/model/area_manager.lua)
- [scen_edit/model/object/area_bridge.lua](../../scen_edit/model/object/area_bridge.lua)
- [scen_edit/model/runtime_model/area_model.lua](../../scen_edit/model/runtime_model/area_model.lua)

**Commands:**
- [resize_area_command.lua](../../scen_edit/command/resize_area_command.lua)

---

## 7. Teams & diplomacy

Teams, allyteams, player-team assignment. Engine team ops bound via the `teams` /
`synced_ctrl` APIs.

**Status:** review (in stable) — add / remove / update team, set ally state, and
change-player-team are Rust-only, backed by a native `TeamManager` snapshot for
undo/redo.

**Model:**
- [scen_edit/model/team_manager.lua](../../scen_edit/model/team_manager.lua)

**Commands:**
- [add_team_command.lua](../../scen_edit/command/add_team_command.lua)
- [remove_team_command.lua](../../scen_edit/command/remove_team_command.lua)
- [update_team_command.lua](../../scen_edit/command/update_team_command.lua)
- [set_ally_command.lua](../../scen_edit/command/set_ally_command.lua)
- [change_player_team_command.lua](../../scen_edit/command/change_player_team_command.lua)
- [team_sync.lua](../../scen_edit/command/sync/team_sync.lua)

---

## 8. Project lifecycle

Save / load / export / sync / start / stop + scenario *info* (project metadata).
Touches filesystem and project state; export commands that read engine pixel data
are gated on the same atlas GL gap as slice 4. `resend_command.lua` (deferred from
slice 0) lands here — it depends on s11n.

**Model:**
- [scen_edit/model/project.lua](../../scen_edit/model/project.lua)
- [scen_edit/model/model.lua](../../scen_edit/model/model.lua) (root)
- [scen_edit/model/scenario_info.lua](../../scen_edit/model/scenario_info.lua) — project-level scenario metadata

**Commands:**
- [set_scenario_info_command.lua](../../scen_edit/command/set_scenario_info_command.lua)
- [scenario_info_sync.lua](../../scen_edit/command/sync/scenario_info_sync.lua)
- [save_command.lua](../../scen_edit/command/save_command.lua)
- [save_images_command.lua](../../scen_edit/command/save_images_command.lua) — gated (atlas read)
- [load_gui_state_command.lua](../../scen_edit/command/load_gui_state_command.lua)
- [start_command.lua](../../scen_edit/command/start_command.lua)
- [stop_command.lua](../../scen_edit/command/stop_command.lua)
- [sync_file_command.lua](../../scen_edit/command/sync_file_command.lua)
- [compile_map_command.lua](../../scen_edit/command/compile_map_command.lua) — was launcher; investigate native
- [reload_meta_model_command.lua](../../scen_edit/command/reload_meta_model_command.lua)
- [export_map_info_command.lua](../../scen_edit/command/export_map_info_command.lua) — gated (atlas read)
- [export_maps_command.lua](../../scen_edit/command/export_maps_command.lua) — gated (atlas read)
- [export_s11n_command.lua](../../scen_edit/command/export_s11n_command.lua)
- [resend_command.lua](../../scen_edit/command/resend_command.lua) — depends on s11n
- [project/copy_custom_project_files_command.lua](../../scen_edit/command/project/copy_custom_project_files_command.lua)
- [project/export_project_command.lua](../../scen_edit/command/project/export_project_command.lua)
- [project/load_project_command_widget.lua](../../scen_edit/command/project/load_project_command_widget.lua)
- [project/reload_into_project_command.lua](../../scen_edit/command/project/reload_into_project_command.lua)
- [project/save_project_info_command.lua](../../scen_edit/command/project/save_project_info_command.lua)
- [project/set_project_name_path_command.lua](../../scen_edit/command/project/set_project_name_path_command.lua)

---

## 9. Triggers + Variables

Bookkeeping, done last. Triggers depend on areas / teams. Variables are
project-scoped values triggers reference. Trigger conditions/actions are
polymorphic nested data — the heaviest serialization shape in the codebase, but
pure project logic (no engine API).

**Model:**
- [scen_edit/model/variable_manager.lua](../../scen_edit/model/variable_manager.lua)
- [scen_edit/model/trigger_manager.lua](../../scen_edit/model/trigger_manager.lua)

**Variable commands:**
- [add_variable_command.lua](../../scen_edit/command/add_variable_command.lua)
- [remove_variable_command.lua](../../scen_edit/command/remove_variable_command.lua)
- [update_variable_command.lua](../../scen_edit/command/update_variable_command.lua)
- [variable_sync.lua](../../scen_edit/command/sync/variable_sync.lua)

**Trigger commands:**
- [add_trigger_command.lua](../../scen_edit/command/add_trigger_command.lua)
- [remove_trigger_command.lua](../../scen_edit/command/remove_trigger_command.lua)
- [update_trigger_command.lua](../../scen_edit/command/update_trigger_command.lua)
- [execute_trigger_command.lua](../../scen_edit/command/execute_trigger_command.lua)
- [execute_trigger_actions_command.lua](../../scen_edit/command/execute_trigger_actions_command.lua)
- [trigger_sync.lua](../../scen_edit/command/sync/trigger_sync.lua)

---

The async-IO model (heightmap import/export, compile, image export) is a design
concern, not a slice — see [docs/design/async-io.md](../design/async-io.md). The
worker shell landed with slice 1; the first job types land with slice 2.

Where ported code lives in the tree is a porting convention — see
[conventions.md](conventions.md#code-structure).
