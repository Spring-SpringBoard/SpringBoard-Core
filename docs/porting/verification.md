---
name: Native UI verification ledger
description: The four-stage process for taking each editor and behaviour from ported to approved, and the status of every one
---

# Native UI verification ledger

Every editor tab and every editor behaviour in the native (Rust) UI moves through
four stages. This file is the single place their status is recorded.

## The four stages

| Stage | Who | Means |
|---|---|---|
| **TODO** | — | Not implemented, or implemented but known incomplete. |
| **DONE** | Claude | Implemented *fully*, matching the original Lua implementation. Not "it renders" — every field, control and mode the Lua version has. |
| **VERIFIED** | Claude | Claude drove it end-to-end and looked at **every** screenshot. The E2E scenario exercises **all** of its options, not a sample. Functionality was compared against the Lua original. The verification result is recorded below: what was confirmed, and which E2E tests ran. |
| **APPROVED** | **User only** | The user double-checked it. **Claude never sets this.** |

Rules:

- Claude may set TODO / DONE / VERIFIED. Claude must **never** write APPROVED.
- **DONE is not VERIFIED.** Code that compiles and renders is DONE at best.
- VERIFIED requires *all* screens of the feature to have been looked at, and the
  test to cover *every* property/control of the tab — ideally one E2E test per
  property, each demonstrating it works.
- A VERIFIED entry must carry its evidence: the confirmed features, and the E2E
  test names (each description ~50 chars max).
- If something later turns out broken, drop it back to TODO and say why.

## How to run

```bash
python3 tools/e2e/ui_driver.py <target> --tag ui:rust
python3 tools/e2e/ui_driver.py <target> --tag ui:rust --update-golden   # re-capture
```

Never run the Lua (`ui:chili` / `ui:rmlui`) cases — they cost time and prove
nothing about the port.

Goldens are `ai-reviewed` until the user runs `tools/e2e/approve_goldens.py`.

---

## Editors

The 14 editors registered by the native UI, in the order they will be worked.
Objects first (the user's priority), then Map, then Env, then Misc.

| # | Tab → Editor | Source | Stage | Evidence |
|---|---|---|---|---|
| 1 | Objects → Units | `editors/objects_units.rs` (+ `object_defs.rs`) | TODO | Present: Add/Brush buttons, team, amount, size, spread, noise, min/max rot per axis, search, def grid with RTT thumbnails. **Missing: the Type and Terrain filters.** Blocked on unit-def bindings — see below. |
| 2 | Objects → Features | `editors/objects_features.rs` (+ `object_defs.rs`) | TODO | Same body as Units. **Missing: the Type / Wreck / Terrain filters.** Lua decides "is a wreck" by stripping `_heap`/`_dead` from the feature name and looking up the unit def; the Wreck/Terrain filters then read *that unit def's* flags. Blocked on the same bindings. |
| 3 | Objects → Properties | `editors/objects_properties.rs` | TODO | |
| 4 | Objects → Collision | `editors/objects_collision.rs` | TODO | |
| 5 | Map → Terrain | `editors/map_terrain.rs` | TODO | |
| 6 | Map → Texture (Paint) | `editors/map_texture.rs` | TODO | |
| 7 | Map → Metal | `editors/map_metal.rs` | TODO | |
| 8 | Map → Grass | `editors/map_grass.rs` | TODO | |
| 9 | Map → Settings | `editors/map_settings.rs` | TODO | |
| 10 | Env → Lighting | `editors/env_lighting.rs` | TODO | |
| 11 | Env → Sky | `editors/env_sky.rs` | TODO | |
| 12 | Env → Water | `editors/env_water.rs` | TODO | |
| 13 | Misc → Info | `editors/misc_info.rs` | TODO | |
| 14 | Misc → Teams | `editors/misc_teams.rs` | TODO | Structurally wrong: Lua is a compact list (swatch + name + Edit + x) with Add in the action strip, and Edit opens a **dialog**. The port inlines every team's fields. Needs rewrite. |

## Editor behaviours

Cross-cutting behaviour, not tied to one tab. These need scenarios of their own.

| # | Behaviour | Where | Stage | Evidence |
|---|---|---|---|---|
| 15 | Selection — click to select a unit/feature/area | `states/state.rs` (DefaultState) | TODO | |
| 16 | Selection — shift-click toggles (multi-select) | `states/state.rs` | TODO | |
| 17 | Selection — box/rectangle select by drag | `states/rectangle_select.rs` | TODO | |
| 18 | Selection — click empty ground clears; Escape clears | `states/state.rs` | TODO | |
| 19 | Selection — the marker renders under the object, green, features only | `states/highlight.rs`, `sbc.rs` | TODO | |
| 20 | Object drag (move) | `states/manipulate.rs` | TODO | |
| 21 | Object rotate (R) | `states/manipulate.rs` | TODO | |
| 22 | Object placement — Set mode (model ghost at cursor) | `states/add_object.rs` | TODO | |
| 23 | Object placement — Brush/scatter mode | `states/add_object.rs` | TODO | |
| 24 | Object delete | `states/`, object commands | TODO | |
| 25 | Copy / Cut / Paste | `actions/clipboard.rs` | TODO | |
| 26 | Undo / Redo | `command_system/history.rs` | TODO | |
| 27 | Toolbar — New / Load / Save / Save As / Import / Export | `actions/` | TODO | |
| 28 | Dialogs — New Project | `panels/new_project_dialog.rs` | TODO | |
| 29 | Dialogs — File (load/save) | `panels/file_dialog.rs` | TODO | |
| 30 | Numeric field — click to edit, type, commit | `panels/fields/numeric.rs`, `panels/input.rs` | TODO | |
| 31 | Numeric field — drag to change; release outside still ends the drag; Shift = fine | `panels/input.rs` | TODO | |
| 32 | Colour field — picker modal, live preview, OK/Cancel | `panels/color_picker.rs` | TODO | |
| 33 | Asset field — picker modal, folder navigation, pick | `panels/asset_picker.rs` | TODO | |
| 34 | Choice / Boolean / String fields | `panels/fields/` | TODO | |
| 35 | Grid view — selection, folder navigation, thumbnails | `panels/grid.rs` | TODO | |
| 36 | Tooltips on every control | `panels/field.rs` (`bind_tooltip`) | TODO | |
| 37 | Brush preview on the map (pattern texture under cursor) | `states/highlight.rs` | TODO | |
| 38 | Ray-trace correctness (click, drag and preview agree) | `states/state.rs` (`cursor`) | TODO | |
| 39 | Dev console | `devconsole/` | TODO | |
| 40 | Chonsole | `chonsole/` | TODO | |
| 41 | Status panel (memory/CPU + recent commands) | not ported | TODO | Not ported at all. |

---

## Blocked on engine bindings

The Objects def filters (items 1 and 2) cannot be finished without these. Lua
reads them straight off `UnitDefs`; `spring-native` does not expose them.

Already exposed on `UnitDefPhysics`: `canFly`, `canMove`, `canHover`,
`floatOnWater`.

Missing, and needed:

| Field | Used by | For |
|---|---|---|
| `isBuilding` | Units "Type", Features "Wreck" | Units vs Buildings |
| `canSubmerge` | Units/Features "Terrain" | the Ground test |
| `waterline` | Units/Features "Terrain" | Ground vs Water |
| `minWaterDepth` | Units/Features "Terrain" | Ground vs Water |

The port mandate ([03-view-rust.md](03-view-rust.md)) says a missing engine
feature is added as a proper binding with a test that fails without it — not
worked around. `canMove` is *not* a stand-in for `isBuilding`, and there is no
substitute at all for the waterline pair, so the Terrain filter cannot be
approximated.

## Verification log

Filled in as each item reaches VERIFIED. Newest last.

*(nothing verified yet — the entries below are the harness fixes that made
verification possible, not feature verification)*

- The E2E harness now runs the native UI through the **same** scenarios as the
  Lua UIs (`--tag ui:rust`), on the premise that the port must behave
  identically. Twelve `ui:rust` cases exist.
- `screenshot_root` captured the X root window and failed intermittently,
  aborting scenarios. It now captures the engine window, like every other shot.
- The modal goldens compared full-frame, which included the dev console's boot
  log — and that log prints pointer addresses that change every run, so those
  goldens could never pass. They now crop to `no-console`.
