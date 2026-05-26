---
name: Phase 3 — Model
description: Per-file status of Lua model layer being ported to Rust
---

# Phase 3 — Model

24 Lua files in [scen_edit/model/](../../scen_edit/model/). Project state, managers, bridges to the engine.

The model is what commands and states *mutate*. It's the hottest coupling in the codebase. Approach: port managers behind a Rust-side facade with the same shape Lua expects, so commands don't all need to flip at once.

## Managers

| Lua | Status | Notes |
|-----|--------|-------|
| [model.lua](../../scen_edit/model/model.lua) | todo | Root — port first |
| [project.lua](../../scen_edit/model/project.lua) | todo | |
| [scenario_info.lua](../../scen_edit/model/scenario_info.lua) | todo | |
| [area_manager.lua](../../scen_edit/model/area_manager.lua) | todo | |
| [assets_manager.lua](../../scen_edit/model/assets_manager.lua) | todo | |
| [brush_manager.lua](../../scen_edit/model/brush_manager.lua) | todo | |
| [extensions_manager.lua](../../scen_edit/model/extensions_manager.lua) | todo | |
| [springmon_manager.lua](../../scen_edit/model/springmon_manager.lua) | todo | |
| [team_manager.lua](../../scen_edit/model/team_manager.lua) | todo | |
| [terrain_manager.lua](../../scen_edit/model/terrain_manager.lua) | todo | |
| [texture_manager.lua](../../scen_edit/model/texture_manager.lua) | todo | |
| [trigger_manager.lua](../../scen_edit/model/trigger_manager.lua) | todo | |
| [variable_manager.lua](../../scen_edit/model/variable_manager.lua) | todo | |

## Data + bridges

| Lua | Status | Notes |
|-----|--------|-------|
| [heightmap.lua](../../scen_edit/model/heightmap.lua) | todo | |
| [area_model.lua](../../scen_edit/model/area_model.lua) | todo | |
| [active_drawing.lua](../../scen_edit/model/active_drawing.lua) | todo | |
| [runtime_model.lua](../../scen_edit/model/runtime_model.lua) | todo | |
| [texture_undo_stack.lua](../../scen_edit/model/texture_undo_stack.lua) | todo | |
| [field_resolver.lua](../../scen_edit/model/field_resolver.lua) | todo | |
| [area_bridge.lua](../../scen_edit/model/area_bridge.lua) | todo | |
| [feature_bridge.lua](../../scen_edit/model/feature_bridge.lua) | todo | |
| [object_bridge.lua](../../scen_edit/model/object_bridge.lua) | todo | |
| [position_bridge.lua](../../scen_edit/model/position_bridge.lua) | todo | |
| [unit_bridge.lua](../../scen_edit/model/unit_bridge.lua) | todo | |

## Subdirs

[scen_edit/model/object/](../../scen_edit/model/object/) and [scen_edit/model/rendering/](../../scen_edit/model/rendering/) and [scen_edit/model/runtime_model/](../../scen_edit/model/runtime_model/) hold further files — enumerate when this phase opens.
