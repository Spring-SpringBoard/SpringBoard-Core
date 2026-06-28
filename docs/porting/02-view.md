---
name: Phase 4 — View (Chili → RmlUi)
description: Migrating UI from Chili to RmlUi
---

# Phase 4 — View: Chili → RmlUi (Lua-side)

118 Lua files under [scen_edit/view/](../../scen_edit/view/). This phase only kills Chili; the view logic stays in Lua. The follow-up phase ([05-view-rust.md](05-view-rust.md)) moves that logic into Rust.

Splitting it in two stages keeps each step small:
1. Chili → RmlUi while the logic is still Lua (easier to verify visually, no FFI to debug).
2. Then Lua RmlUi handlers → Rust, one panel at a time.

Some RmlUi work exists in side branches and may be cherry-picked in once this phase opens. See [rmlui-side-branches.md](rmlui-side-branches.md) for an inventory of what those branches contain and how they relate.

## Approach

Per-window: build the RmlUi version next to the Chili version, switch the loader, leave the Chili file for one cycle, then delete. The app stays usable throughout.

## Floating windows (start here — smallest surface)

| Chili source | Status |
|--------------|--------|
| [floating/status_window.lua](../../scen_edit/view/floating/status_window.lua) | todo |
| [floating/command_window.lua](../../scen_edit/view/floating/command_window.lua) | todo |
| [floating/control_buttons.lua](../../scen_edit/view/floating/control_buttons.lua) | todo |
| [floating/top_left_menu.lua](../../scen_edit/view/floating/top_left_menu.lua) | todo |
| [floating/bottom_bar.lua](../../scen_edit/view/floating/bottom_bar.lua) | todo |
| [floating/team_selector.lua](../../scen_edit/view/floating/team_selector.lua) | todo |

## Remaining Chili-side areas

Each becomes its own task block when we open this phase. High-level inventory:

| Area | Status |
|------|--------|
| [view/main_window/](../../scen_edit/view/main_window/) | todo |
| [view/dialog/](../../scen_edit/view/dialog/) | todo |
| [view/object/](../../scen_edit/view/object/) | todo |
| [view/trigger/](../../scen_edit/view/trigger/) | todo |
| [view/general/](../../scen_edit/view/general/) | todo |
| [view/map/](../../scen_edit/view/map/) | todo |
| [view/actions/](../../scen_edit/view/actions/) | todo |
| [view/fields/](../../scen_edit/view/fields/) | todo |
| Top-level (asset_view, grid_view, editor, ...) | todo |

Enumerate file-by-file once Phases 1–3 are far enough that the underlying data shapes are stable. Building UI on a moving model multiplies churn.

## Exit criteria

All view files RmlUi-based, Chili dependency removed, Chili-specific helpers ([scen_edit/view/ui_controls.lua](../../scen_edit/view/ui_controls.lua) etc.) deleted. View *logic* is still Lua at this point — that's Phase 5.
