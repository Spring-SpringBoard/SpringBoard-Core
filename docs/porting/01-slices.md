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
| 1 | [Terrain](#1-terrain) — shape / level / smooth / metal brushes | done (wip; flipped to Rust-only) |
| 2 | [Heightmap](#2-heightmap) — load (sync) + import / export (async IO) | todo |
| 3 | [Map settings](#3-map-settings) — sun / atmosphere / water / map-rendering | todo (setters bound; undo needs gl getters) |
| 4 | [Textures](#4-textures) — diffuse / shading / terrain texture / cache + grass + DNTS | blocked (texture-atlas GL) |
| 5 | [Objects](#5-objects) — units & features add / remove / set / move (needs s11n) | todo (large) |
| 6 | [Areas](#6-areas) | todo |
| 7 | [Teams & diplomacy](#7-teams--diplomacy) | todo |
| 8 | [Project lifecycle](#8-project-lifecycle) — save / load / export / sync / start / stop + scenario-info | todo |
| 9 | [Triggers + Variables](#9-triggers--variables) — depends on areas, teams | todo (last) |

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

**Rust files** (under [native/src/sbc/commands/](../../native/src/sbc/commands/)):
`commands_api.rs` (public surface) + `command_system/` (`command.rs`,
`context.rs`, `command_manager.rs`, `registry.rs`, `ignored.rs`, and the four
control commands). Transport (`{tag, data}` decode) lives at the `SBC` boundary
in [sbc.rs](../../native/src/sbc/sbc.rs).

Convention: each slice is a directory; `mod.rs` files only wire submodules, never
hold code. Feature-slice managers (e.g. terrain's `TerrainManager`) construct
through `sbc.rs`.

**Lua files**:
- [scen_edit/command/command.lua](../../scen_edit/command/command.lua) — base class
- [scen_edit/command/command_manager.lua](../../scen_edit/command/command_manager.lua) — bridge (`Spring.InvokeNativeModule` call + `nativeCommandsOnly` allowlist) and dispatch on the Lua side
- [scen_edit/command/compound_command.lua](../../scen_edit/command/compound_command.lua) — base for grouped commands

The bridge sends every command to Rust via `Spring.InvokeNativeModule(json.encode(msg:serialize()))`. Lua execution **also** runs (parallel) unless the class name appears in `nativeCommandsOnly`. Slice 0 leaves that allowlist empty — feature slices populate it as they land.

**Deferred to slice 1 (first feature slice that flips a command to Rust-only):**

These exist on the Lua side and are required for full 1:1 parity once Rust is the only executor. Until then Lua handles them; slice 0 leaves them out by design, not by omission.

- `__cmd_id` allocation on every executed command (Rust counterpart to Lua's `idCount`).
- Widget notify after `execute` / `undo` / `redo` / `clear_*` / `undo_list_add` (when it pops oldest) — Lua dispatches `WidgetCommandExecuted` / `WidgetCommandUndo` / `WidgetCommandRedo` / `WidgetCommandClearUndoStack` / `WidgetCommandClearRedoStack` / `WidgetCommandRemoveFirstUndo` to the widget. Rust needs the equivalent via `send_lua_uimsg`, matching `scen_edit/message/message_manager.lua`'s prefix-framed wire format.
- `display()` method on commands (Lua returns `self.className`; `CompoundCommand` returns the first sub-command's display). Required for the `display` field of `WidgetCommandExecuted`.

**Out of scope for slice 0** (handled by their feature slices):
- [merge_command.lua](../../scen_edit/command/merge_command.lua) — depends on `SetWaterParams` / `SetAtmosphere` / `SetSunParameters` inner commands; lands with slice 3 (map settings).
- [resend_command.lua](../../scen_edit/command/resend_command.lua) — depends on s11n libs; lands with slice 8 (project lifecycle).

---

## 1. Terrain

Brush-based heightmap and metal-map editing. Engine-side via `Spring.SetHeightMap` / `Spring.SetMetalAmount` / `Spring.AddHeightMap`, all bound natively.

**Status:** done in wip — 4 brush commands + brush-settings, flipped to Rust-only via `nativeCommandsOnly`. Needs in-game verification (the slice-0 widget-notify path is exercised here).

**Model:**
- [scen_edit/model/terrain_manager.lua](../../scen_edit/model/terrain_manager.lua) — brush state, listeners, generated metadata
- [scen_edit/model/heightmap.lua](../../scen_edit/model/heightmap.lua)
- [scen_edit/model/rendering/texture_undo_stack.lua](../../scen_edit/model/rendering/texture_undo_stack.lua) (also used by textures)

**Commands:**
- [abstract_terrain_modify_command.lua](../../scen_edit/command/abstract_terrain_modify_command.lua) — shared base
- [terrain_shape_modify_command.lua](../../scen_edit/command/terrain_shape_modify_command.lua)
- [terrain_level_command.lua](../../scen_edit/command/terrain_level_command.lua)
- [terrain_smooth_command.lua](../../scen_edit/command/terrain_smooth_command.lua)
- [terrain_metal_command.lua](../../scen_edit/command/terrain_metal_command.lua)
- [set_heightmap_brush_command.lua](../../scen_edit/command/set_heightmap_brush_command.lua)

---

## 2. Heightmap

Whole-map heightmap load + image import/export. **Not GL-blocked** — see
`spring-bar/rust/crates/spring-native/SBC_PORT_MISSING_BINDINGS.md`. Load uses
bound `set_height_map`; import/export do image decode/encode in Rust (the `image`
crate), replacing what the spring-launcher used to do over IPC.

**Two parts:**
- **Load (synchronous):** `LoadMapCommand` is a `Spring.SetHeightMap` loop over a
  raw float array that arrives in the command payload. No file IO, no background
  thread. Port directly.
- **Import / export (async IO):** decode/encode an image file. File IO + image
  work runs on a background worker thread (must not touch the engine); the engine
  thread applies/reads heights. Needs the IO-worker + `widget:Update` poll (see
  "Async IO" below).

**Model:**
- [scen_edit/model/heightmap.lua](../../scen_edit/model/heightmap.lua) (shared with slice 1)

**Commands:**
- [load_map_command.lua](../../scen_edit/command/load_map_command.lua) — synchronous
- [import_heightmap_command.lua](../../scen_edit/command/import_heightmap_command.lua) — async (image decode in Rust; was launcher `ImportSBHeightmap`)
- [export_heightmap_command.lua](../../scen_edit/command/textures/export_heightmap_command.lua) — async (read heights via `get_ground_height`, encode image in Rust; was launcher `ConvertSBHeightmap`)

---

## 3. Map settings

General map rendering config: sun lighting, atmosphere, water, map-rendering
params. These are **map-wide config**, distinct from scenario *info* (project
metadata, which is in slice 8). Should land early.

**Status / blocker:** mostly engine-blocked. The setters are bound but their
param structs (`AtmosphereParams`, `SunLightingParams`, `WaterParams`,
`MapRenderingParams`) are `_unused: u8` stubs in the generated bindings — calling
them carries no data (no-ops) until the engine defines the struct fields + wires
the apply. See the engine note, Category A. The one exception that ports today is
`set_sun_parameters_command.lua` (`Spring.SetSunDirection` → bound
`set_sun_direction(Float3, intensity)`). Undo for any of these additionally needs
the `gl.*` getters (also unbound). These commands are `_execute_unsynced`, so the
bridge would also need to route them to native (currently they go cross-state to
the widget). Net: defer this slice until the engine structs are fleshed out.

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

Map texturing (terrain texture, diffuse, shading, grass, DNTS). **Blocked** on
the GL texture-atlas operations (`gl.RenderToTexture` / `ReadPixels` / `CreateTexture`
/ shaders), which have no native binding and need a GL context — see the engine
note, Category B. Grass/metal *export* is doable (read via bound APIs + encode in
Rust) but the diffuse/shading atlas read/write is the real blocker.

**Model:**
- [scen_edit/model/texture_manager.lua](../../scen_edit/model/texture_manager.lua)
- [scen_edit/model/rendering/active_drawing.lua](../../scen_edit/model/rendering/active_drawing.lua)
- [scen_edit/model/rendering/texture_undo_stack.lua](../../scen_edit/model/rendering/texture_undo_stack.lua) (shared with slice 1)
- [scen_edit/model/assets_manager.lua](../../scen_edit/model/assets_manager.lua)
- [scen_edit/model/brush_manager.lua](../../scen_edit/model/brush_manager.lua)

**Commands:**
- [terrain_change_texture_command.lua](../../scen_edit/command/terrain_change_texture_command.lua) — blocked (atlas)
- [widget_terrain_change_texture_command.lua](../../scen_edit/command/widget_terrain_change_texture_command.lua) — blocked (atlas, unsynced)
- [terrain_grass_command.lua](../../scen_edit/command/terrain_grass_command.lua)
- [cache_texture_command.lua](../../scen_edit/command/cache_texture_command.lua)
- [import_diffuse_command.lua](../../scen_edit/command/import_diffuse_command.lua) — blocked (atlas)
- [import_shading_image_command.lua](../../scen_edit/command/import_shading_image_command.lua) — blocked (atlas)
- [load_texture_command.lua](../../scen_edit/command/load_texture_command.lua) — blocked (atlas)
- [load_grass_map_command.lua](../../scen_edit/command/load_grass_map_command.lua)
- [load_metal_map_command.lua](../../scen_edit/command/load_metal_map_command.lua)
- [export_diffuse_command.lua](../../scen_edit/command/textures/export_diffuse_command.lua) — blocked (atlas read)
- [export_shading_textures_command.lua](../../scen_edit/command/textures/export_shading_textures_command.lua) — blocked (atlas read)
- [export_grass_command.lua](../../scen_edit/command/textures/export_grass_command.lua) — async IO, doable
- [export_metal_command.lua](../../scen_edit/command/textures/export_metal_command.lua) — async IO, doable

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

## Widget commands — not a slice

Widget commands aren't deferred as a catch-all. Each is part of the feature slice
it serves and is listed there:

- `widget_terrain_change_texture_command` → slice 4 (textures)
- `widget_follow_unit_command` → slice 5 (objects); genuinely widget-only, stays Lua
- `widget_command_executed` / undo / redo / clear / remove-first → slice 0
  (the command-system widget-notify path; already handled)

The remaining genuinely widget-only ones (display text, unit say, draw texture,
execute-unsynced-action) are unsynced UI helpers; they stay Lua until the view
layer moves to Rust (Phase 2/3). Listed for completeness:
- [widget_display_text.lua](../../scen_edit/command/widget_display_text.lua)
- [widget_unit_say_command.lua](../../scen_edit/command/widget_unit_say_command.lua)
- [widget_draw_texture_command.lua](../../scen_edit/command/widget_draw_texture_command.lua)
- [widget_execute_unsynced_action_command.lua](../../scen_edit/command/widget_execute_unsynced_action_command.lua)

## Async IO (heightmap import/export, compile, image export)

Import/export/compile do file IO + image decode/encode. Rule: **the background
thread never touches the engine; the engine thread never does file IO.**

- Engine thread (on command dispatch): read engine data into an owned buffer
  (export) — fast memory read, no IO. Hand the buffer to the worker.
- Background worker thread: file read/write + image decode/encode on owned
  buffers only. No engine access.
- Engine thread (on drain): apply results (e.g. `set_height_map` for import).

Drain point: there's no native per-frame callin (see the engine note, Category 0),
so a throttled `widget:Update` pokes the plugin via
`InvokeNativeModule(json.encode({tag="poll_io"}))` and the plugin drains completed
jobs on that call. `widget:Update` (not `gadget:GameFrame`) because GameFrame
doesn't fire while paused and SBC is effectively always paused.

## Where things go in Rust

- Per-command Rust file: [native/src/sbc/commands/](../../native/src/sbc/commands/)`<slice>/`. Each file owns its serde struct, the `inventory::submit!` registration, and the execute/unexecute logic.
- Per-manager Rust file: a per-slice `model`/manager module.
- The command-system internals + the single public `commands_api` surface live under [native/src/sbc/commands/command_system/](../../native/src/sbc/commands/command_system/).
- Cross-slice managers (texture undo stack, heightmap) live where the first slice that needs them puts them; later slices reuse.
