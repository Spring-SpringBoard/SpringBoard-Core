---
name: Phase 1 — Commands
description: Per-file status of all Lua commands being ported to Rust
---

# Phase 1 — Commands

85 Lua command files: 69 at the top level of [scen_edit/command/](../../scen_edit/command/), plus three subdirs — [textures/](../../scen_edit/command/textures/) (5), [sync/](../../scen_edit/command/sync/) (5), [project/](../../scen_edit/command/project/) (6).

5 of those (the terrain commands) already have partial Rust counterparts on a side branch that get re-landed as part of Phase 0/1.

Status terms in [README.md](README.md).

## Infrastructure (base classes — no 1:1 port)

| Lua | Status | Notes |
|-----|--------|-------|
| [command.lua](../../scen_edit/command/command.lua) | todo | Base `Command` class + `CompoundCommand`. Counterpart is a trait in Rust. |
| [command_manager.lua](../../scen_edit/command/command_manager.lua) | todo | Dispatch + undo/redo stack. Counterpart in Rust manages the registry and the bridge to Lua. |

## Leaf commands — port first (no model/state deps beyond trivial)

| Lua | Status |
|-----|--------|
| [add_variable_command.lua](../../scen_edit/command/add_variable_command.lua) | todo |
| [remove_variable_command.lua](../../scen_edit/command/remove_variable_command.lua) | todo |
| [update_variable_command.lua](../../scen_edit/command/update_variable_command.lua) | todo |
| [add_team_command.lua](../../scen_edit/command/add_team_command.lua) | todo |
| [remove_team_command.lua](../../scen_edit/command/remove_team_command.lua) | todo |
| [update_team_command.lua](../../scen_edit/command/update_team_command.lua) | todo |
| [set_ally_command.lua](../../scen_edit/command/set_ally_command.lua) | todo |
| [change_player_team_command.lua](../../scen_edit/command/change_player_team_command.lua) | todo |
| [set_scenario_info_command.lua](../../scen_edit/command/set_scenario_info_command.lua) | todo |
| [set_global_los_command.lua](../../scen_edit/command/set_global_los_command.lua) | todo |
| [set_atmosphere_command.lua](../../scen_edit/command/set_atmosphere_command.lua) | todo |
| [set_sun_lighting_command.lua](../../scen_edit/command/set_sun_lighting_command.lua) | todo |
| [set_sun_parameters_command.lua](../../scen_edit/command/set_sun_parameters_command.lua) | todo |
| [set_water_params_command.lua](../../scen_edit/command/set_water_params_command.lua) | todo |
| [set_map_rendering_params_command.lua](../../scen_edit/command/set_map_rendering_params_command.lua) | todo |
| [set_heightmap_brush_command.lua](../../scen_edit/command/set_heightmap_brush_command.lua) | todo |
| [set_multiple_command_mode_command.lua](../../scen_edit/command/set_multiple_command_mode_command.lua) | todo |

## Terrain (already partially done in side branch)

| Lua | Status |
|-----|--------|
| [abstract_terrain_modify_command.lua](../../scen_edit/command/abstract_terrain_modify_command.lua) | todo |
| [terrain_level_command.lua](../../scen_edit/command/terrain_level_command.lua) | todo |
| [terrain_metal_command.lua](../../scen_edit/command/terrain_metal_command.lua) | todo |
| [terrain_shape_modify_command.lua](../../scen_edit/command/terrain_shape_modify_command.lua) | todo |
| [terrain_smooth_command.lua](../../scen_edit/command/terrain_smooth_command.lua) | todo |

## Trigger / actions

| Lua | Status |
|-----|--------|
| [add_trigger_command.lua](../../scen_edit/command/add_trigger_command.lua) | todo |
| [remove_trigger_command.lua](../../scen_edit/command/remove_trigger_command.lua) | todo |
| [update_trigger_command.lua](../../scen_edit/command/update_trigger_command.lua) | todo |
| [execute_trigger_command.lua](../../scen_edit/command/execute_trigger_command.lua) | todo |
| [execute_trigger_actions_command.lua](../../scen_edit/command/execute_trigger_actions_command.lua) | todo |

## Object lifecycle

| Lua | Status |
|-----|--------|
| [add_object_command.lua](../../scen_edit/command/add_object_command.lua) | todo |
| [remove_object_command.lua](../../scen_edit/command/remove_object_command.lua) | todo |
| [set_object_command.lua](../../scen_edit/command/set_object_command.lua) | todo |
| [set_object_param_command.lua](../../scen_edit/command/set_object_param_command.lua) | todo |

## Terrain / map

| Lua | Status |
|-----|--------|
| [terrain_change_texture_command.lua](../../scen_edit/command/terrain_change_texture_command.lua) | todo |
| [terrain_grass_command.lua](../../scen_edit/command/terrain_grass_command.lua) | todo |
| [resize_area_command.lua](../../scen_edit/command/resize_area_command.lua) | todo |
| [compile_map_command.lua](../../scen_edit/command/compile_map_command.lua) | todo |
| [load_map_command.lua](../../scen_edit/command/load_map_command.lua) | todo |
| [load_grass_map_command.lua](../../scen_edit/command/load_grass_map_command.lua) | todo |
| [load_metal_map_command.lua](../../scen_edit/command/load_metal_map_command.lua) | todo |
| [load_model_command.lua](../../scen_edit/command/load_model_command.lua) | todo |
| [load_texture_command.lua](../../scen_edit/command/load_texture_command.lua) | todo |
| [load_gui_state_command.lua](../../scen_edit/command/load_gui_state_command.lua) | todo |
| [cache_texture_command.lua](../../scen_edit/command/cache_texture_command.lua) | todo |
| [import_diffuse_command.lua](../../scen_edit/command/import_diffuse_command.lua) | todo |
| [import_heightmap_command.lua](../../scen_edit/command/import_heightmap_command.lua) | todo |
| [import_shading_image_command.lua](../../scen_edit/command/import_shading_image_command.lua) | todo |

## Save / export / lifecycle

| Lua | Status |
|-----|--------|
| [save_command.lua](../../scen_edit/command/save_command.lua) | todo |
| [save_images_command.lua](../../scen_edit/command/save_images_command.lua) | todo |
| [export_map_info_command.lua](../../scen_edit/command/export_map_info_command.lua) | todo |
| [export_maps_command.lua](../../scen_edit/command/export_maps_command.lua) | todo |
| [export_s11n_command.lua](../../scen_edit/command/export_s11n_command.lua) | todo |
| [start_command.lua](../../scen_edit/command/start_command.lua) | todo |
| [stop_command.lua](../../scen_edit/command/stop_command.lua) | todo |
| [sync_file_command.lua](../../scen_edit/command/sync_file_command.lua) | todo |
| [reload_meta_model_command.lua](../../scen_edit/command/reload_meta_model_command.lua) | todo |

## Undo / control

| Lua | Status |
|-----|--------|
| [compound_command.lua](../../scen_edit/command/compound_command.lua) | todo |
| [undo_command.lua](../../scen_edit/command/undo_command.lua) | todo |
| [redo_command.lua](../../scen_edit/command/redo_command.lua) | todo |
| [clear_undo_redo_command.lua](../../scen_edit/command/clear_undo_redo_command.lua) | todo |
| [merge_command.lua](../../scen_edit/command/merge_command.lua) | todo |
| [resend_command.lua](../../scen_edit/command/resend_command.lua) | todo |

## Widget commands (`widget_*`)

These run on the unsynced side; check whether each still belongs in Rust before porting.

| Lua | Status |
|-----|--------|
| [widget_command_executed.lua](../../scen_edit/command/widget_command_executed.lua) | todo |
| [widget_display_text.lua](../../scen_edit/command/widget_display_text.lua) | todo |
| [widget_draw_texture_command.lua](../../scen_edit/command/widget_draw_texture_command.lua) | todo |
| [widget_execute_unsynced_action_command.lua](../../scen_edit/command/widget_execute_unsynced_action_command.lua) | todo |
| [widget_follow_unit_command.lua](../../scen_edit/command/widget_follow_unit_command.lua) | todo |
| [widget_terrain_change_texture_command.lua](../../scen_edit/command/widget_terrain_change_texture_command.lua) | todo |
| [widget_unit_say_command.lua](../../scen_edit/command/widget_unit_say_command.lua) | todo |

## Texture export ([scen_edit/command/textures/](../../scen_edit/command/textures/))

| Lua | Status |
|-----|--------|
| [export_diffuse_command.lua](../../scen_edit/command/textures/export_diffuse_command.lua) | todo |
| [export_grass_command.lua](../../scen_edit/command/textures/export_grass_command.lua) | todo |
| [export_heightmap_command.lua](../../scen_edit/command/textures/export_heightmap_command.lua) | todo |
| [export_metal_command.lua](../../scen_edit/command/textures/export_metal_command.lua) | todo |
| [export_shading_textures_command.lua](../../scen_edit/command/textures/export_shading_textures_command.lua) | todo |

## Sync ([scen_edit/command/sync/](../../scen_edit/command/sync/))

| Lua | Status |
|-----|--------|
| [object_sync.lua](../../scen_edit/command/sync/object_sync.lua) | todo |
| [scenario_info_sync.lua](../../scen_edit/command/sync/scenario_info_sync.lua) | todo |
| [team_sync.lua](../../scen_edit/command/sync/team_sync.lua) | todo |
| [trigger_sync.lua](../../scen_edit/command/sync/trigger_sync.lua) | todo |
| [variable_sync.lua](../../scen_edit/command/sync/variable_sync.lua) | todo |

## Project subcommands ([scen_edit/command/project/](../../scen_edit/command/project/))

| Lua | Status |
|-----|--------|
| [copy_custom_project_files_command.lua](../../scen_edit/command/project/copy_custom_project_files_command.lua) | todo |
| [export_project_command.lua](../../scen_edit/command/project/export_project_command.lua) | todo |
| [load_project_command_widget.lua](../../scen_edit/command/project/load_project_command_widget.lua) | todo |
| [reload_into_project_command.lua](../../scen_edit/command/project/reload_into_project_command.lua) | todo |
| [save_project_info_command.lua](../../scen_edit/command/project/save_project_info_command.lua) | todo |
| [set_project_name_path_command.lua](../../scen_edit/command/project/set_project_name_path_command.lua) | todo |
