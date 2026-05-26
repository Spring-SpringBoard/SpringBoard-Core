---
name: Phase 2 — State
description: Per-file status of Lua state classes being ported to Rust
---

# Phase 2 — State

21 Lua state files in [scen_edit/state/](../../scen_edit/state/). Editor states (brush, selection, drag, etc.). Likely a strategy pattern in Lua — confirm shape before designing the Rust counterpart.

Don't start until Phase 1 commands these states depend on are at least at review. State and commands are coupled (states fire commands).

## Files

| Lua | Status | Notes |
|-----|--------|-------|
| [abstract_state.lua](../../scen_edit/state/abstract_state.lua) | todo | Base — port first |
| [state_manager.lua](../../scen_edit/state/state_manager.lua) | todo | Dispatch — port second |
| [default_state.lua](../../scen_edit/state/default_state.lua) | todo | |
| [abstract_heightmap_editing_state.lua](../../scen_edit/state/abstract_heightmap_editing_state.lua) | todo | |
| [abstract_map_editing_state.lua](../../scen_edit/state/abstract_map_editing_state.lua) | todo | |
| [add_object_state.lua](../../scen_edit/state/add_object_state.lua) | todo | |
| [add_rect_state.lua](../../scen_edit/state/add_rect_state.lua) | todo | |
| [brush_object_state.lua](../../scen_edit/state/brush_object_state.lua) | todo | |
| [drag_horizontal_state.lua](../../scen_edit/state/drag_horizontal_state.lua) | todo | |
| [drag_object_state.lua](../../scen_edit/state/drag_object_state.lua) | todo | |
| [grass_editing_state.lua](../../scen_edit/state/grass_editing_state.lua) | todo | |
| [metal_editing_state.lua](../../scen_edit/state/metal_editing_state.lua) | todo | |
| [rectangle_select_state.lua](../../scen_edit/state/rectangle_select_state.lua) | todo | |
| [resize_area_state.lua](../../scen_edit/state/resize_area_state.lua) | todo | |
| [rotate_object_state.lua](../../scen_edit/state/rotate_object_state.lua) | todo | |
| [select_object_state.lua](../../scen_edit/state/select_object_state.lua) | todo | |
| [select_object_type_state.lua](../../scen_edit/state/select_object_type_state.lua) | todo | |
| [terrain_change_dnts_state.lua](../../scen_edit/state/terrain_change_dnts_state.lua) | todo | |
| [terrain_change_texture_state.lua](../../scen_edit/state/terrain_change_texture_state.lua) | todo | |
| [terrain_set_state.lua](../../scen_edit/state/terrain_set_state.lua) | todo | |
| [terrain_shape_modify_state.lua](../../scen_edit/state/terrain_shape_modify_state.lua) | todo | |
| [terrain_smooth_state.lua](../../scen_edit/state/terrain_smooth_state.lua) | todo | |

## Dispatch

State manager picks active state. Run Lua + Rust managers in parallel during port, flipping per-state, or hold off until the full set is ready and switch wholesale — decide once we know the manager's shape.
