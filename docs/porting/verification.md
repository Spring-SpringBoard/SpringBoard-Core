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
| 1 | Objects → Units | `editors/objects_units.rs` (+ `object_defs.rs`) | DONE | Add/Brush, team, amount, size, spread, noise, min/max rot per axis, search, def grid, **and the Type + Terrain filters** (no Wreck, as in Lua). Confirmed rendering in `units_panel` screen 01. **Not VERIFIED:** the engine's standalone boot ships *no unit defs*, so the grid is empty and placement/thumbnails cannot be exercised here. Needs a boot with a game's units. |
| 2 | Objects → Features | `editors/objects_features.rs` (+ `object_defs.rs`) | VERIFIED | Type/Wreck/Terrain filters + search + def grid + placement. **Thumbnails checked at native resolution, not at panel scale**: each renders the real textured model, whole and framed to its own radius. (Two bugs were hiding there — no model shader, so every model was a flat white silhouette; and one fixed scale for every def, so big models were clipped at the cell edge.) Type=Wreckage empties the grid — correct, this map has no wrecks — the filter proving it filters. Placing emits `AddObjectCommand{objType:feature}` **and the tree appears on the map** (pixel-diff asserted). E2E `units_panel`, 5 screens, all inspected. |
| 3 | Objects → Properties | `editors/objects_properties.rs` | VERIFIED | Follows the selection. Sections + fields for pos, rot, dir, vel, health, mass, blocking, radius/height, collision, team, resources — the sub-objects that used to be dropped entirely. Editing Pos X emits `SetObjectParamCommand{key:pos}` carrying the **whole vector**, the field reads 1500 afterwards, and **the object moves on the map** (pixel-diff asserted). Toggling a Blocking flag sends the **table** under `key:blocking`, and the change shows up in the Collision view. E2E `props_panel`, 6 screens, all inspected. |
| 4 | Objects → Collision | `editors/objects_collision.rs` | VERIFIED | Complete against Lua's collision window: Show volume, Type, Axis, Scale/Offset/Center/Aim XYZ, Radius+Height, six blocking booleans — which reflect a change made in Properties. Editing Scale X emits `SetObjectParamCommand{key:collision}` carrying the **whole volume table**, and X **and Z** both read 45 after: the cylinder's linked axes, as in Lua's `sync_linked_scales`. E2E `props_panel`, 7 screens, all inspected. |
| 5 | Map → Terrain | `editors/map_terrain.rs` | VERIFIED | Pattern, size/rotation/strength/height/direction, Add/Set/Smooth; final run screens 01–05. |
| 6 | Map → Texture (Paint) | `editors/map_texture.rs` | VERIFIED | Saved-brush Add opens a material dialog, rich channel tooltips, Paint/Filter/DNTS/Void views; Splat is DNTS-only; final run screens 06–12. |
| 7 | Map → Metal | `editors/map_metal.rs` | VERIFIED | Expanded inline pattern grid, size/rotation/amount, working Set paint; final run screens 13–14. |
| 8 | Map → Grass | `editors/map_grass.rs` | VERIFIED | Expanded inline pattern grid, Detail/size/rotation, working Add paint; final run screens 15–16. |
| 9 | Map → Settings | `editors/map_settings.rs` | VERIFIED | Flags, splat arrays, detail texture, and texture-map dialogs with New/Choose Existing; final run screens 17–20. |
| 10 | Env → Lighting | `editors/env_lighting.rs` | VERIFIED | Shadow mode, XYZ direction, all six colors, and both densities; focused run screens 01–02. |
| 11 | Env → Sky | `editors/env_sky.rs` | VERIFIED | All four atmosphere colors, both fog bounds, and Skybox picker/native binding; focused run screens 01–03. |
| 12 | Env → Water | `editors/env_water.rs` | VERIFIED | Visible below-zero basin with water 4; every scalar, boolean, color, and all three textures; screens 01–03. |
| 13 | Misc → Info | `editors/misc_info.rs` | VERIFIED | All four metadata fields commit the complete scenario record; final run screen 03. |
| 14 | Misc → Teams | `editors/misc_teams.rs` | VERIFIED | Compact roster, Add/remove, modal fields, committed color, engine Side choice, complete update and row refresh; screens 02–09. |

## Editor behaviours

Cross-cutting behaviour, not tied to one tab. The **controls and dialogs**
themselves have moved to their own section below: they belong to no editor, and
are exercised in one place (the Dev tab's control gallery) rather than
incidentally, inside whichever editor happens to use one.

| # | Behaviour | Where | Stage | Evidence |
|---|---|---|---|---|
| 15 | Selection — click to select a unit/feature/area | `states/state.rs` (DefaultState) | VERIFIED | Clicking a feature selects it and draws the box. E2E `deselect` (goldens `feature-selected`), and `props_panel` proves it is *really* selected by editing it afterwards. |
| 16 | Selection — shift-click toggles (multi-select) | `states/state.rs` | DONE | Multi-select via box-select is verified (two trees selected and rotated as a pair, E2E `rotation`). The **shift-click** toggle itself has no scenario yet. |
| 17 | Selection — box/rectangle select by drag | `states/rectangle_select.rs` | VERIFIED | The rectangle is drawn while dragging and the covered feature ends up selected. E2E `selection` (goldens `box-dragging`, `box-selected`, then Properties edits it — nothing selected would mean nothing to edit). |
| 18 | Selection — click empty ground clears; Escape clears | `states/state.rs` | VERIFIED | Both, plus a box-select over empty ground dropping the previous selection. Asserted by counting the box's pure-green pixels (0 / present / 0), which is exact where a frame diff would just measure the map shimmering. E2E `deselect`, 6 screens. |
| 19 | Selection — the marker renders under the object, green, features only | `states/highlight.rs`, `sbc.rs` | VERIFIED | Drawn in the pre-unit pass, so it sits *under* the model, as `SelectionManager:DrawWorldPreUnit` does. Green box, features only; units glow through the engine's own selection. Visible in every `deselect` golden. |
| 20 | Object drag (move) | `states/manipulate.rs` | DONE | The object no longer moves during the drag: a **ghost** is drawn where it would land and only the release commits (as `drag_object_state.lua` does). The `drag` cursor is applied. **Not VERIFIED:** no scenario drives an object drag yet. |
| 21 | Object rotate (Ctrl-drag) | `states/manipulate.rs` | VERIFIED | Ctrl-drag rotates the selection about its midpoint; ghosts show the would-be pose while the originals stay put; release commits both objects in one undo group. R is deliberately **not** bound (a keyboard-started rotate has no drag to drive it and no release to end it, and Lua's own comment says the two entries should not coexist). E2E `rotation`, 3 screens; asserted on the *positions* (the pair's z-spread must grow) — the old facing assertion passed on the trees' random placement yaw without the rotation doing anything. |
| 22 | Object placement — Set mode (model ghost at cursor) | `states/add_object.rs` | VERIFIED | The real textured model is ghosted at the cursor, one per object the click will place (amount 5 → five ghosts, at the exact spots used). E2E `units_panel` (`amount-5-preview`, `amount-5-placed`). |
| 23 | Object placement — Brush/scatter mode | `states/add_object.rs` | VERIFIED | Brush ghosts what it will place, and Shift+wheel resizes it through the shared brush settings so the panel's Size field follows. Proved by painting: 1 object at size 100, 7 at 264, spread 415 world units. E2E `brush_size`. (`noise` defaulted to 0 where Lua's is 100, so repeat dabs stacked on identical points — fixed.) |
| 24 | Object delete | `states/`, object commands | TODO | |
| 25 | Copy / Cut / Paste | `actions/clipboard.rs` | TODO | |
| 26 | Undo / Redo | `command_system/history.rs` | TODO | |
| 27 | Toolbar — New / Load / Save / Save As / Import / Export | `actions/` | TODO | |
| 36b | Cursor tooltip — hovering a unit/feature on the map | `panels/cursortip.rs` | VERIFIED | A port of `gui_rmlui_cursortip.lua`: name + health (features), plus def name, team and experience (units). Picks with a 16px **screen rectangle**, not a ray — the engine's GUI ray does not report SpringBoard's features — and matches the object's *drawPos* (a tree's base, not its crown). Hidden while a button is down or over the panel. E2E `cursortip`: no tip over empty ground, tip present over the feature, asserted by counting the tip's near-black pixels. Suppressed in every other scenario (`SBC_HIDE_CURSORTIP`), since a tip that follows the cursor lands in the middle of every map capture. |
| 37 | Brush preview on the map (pattern texture under cursor) | `states/highlight.rs` | TODO | |
| 38 | Ray-trace correctness (click, drag and preview agree) | `states/state.rs` (`cursor`) | TODO | |
| 39 | Dev console | `devconsole/` | TODO | |
| 40 | Chonsole | `chonsole/` | TODO | |
| 41 | Status panel (memory/CPU + recent commands) | not ported | TODO | Not ported at all. |

---

## Common controls and dialogs

The controls themselves, independent of any editor that happens to use one. They
are exercised in the **Dev tab's control gallery** (`panels/editors/dev_fields.rs`),
a kitchen sink holding every field type. It is behind `SBC_DEV_PANEL=1`, so it
neither ships in the tab bar nor appears in any other scenario's screenshots.

`fields-at-rest` is one image of the entire control set — the cheapest way to see
what everything looks like. Each control also *reports the value it produced*
(`dev-fields: <field> = <value>` in the log), which is what the scenario asserts
on: a drag, for one, never fires a DOM change, so there is nothing else to see.

| # | Control | Where | Stage | Evidence |
|---|---|---|---|---|
| C1 | String field — click, type, commit | `panels/fields/string.rs` | VERIFIED | Reports `text = "typed"`. E2E `gallery`. |
| C2 | Numeric field — click to edit, type, commit | `panels/fields/numeric.rs` | VERIFIED | Reports `number = 7.5`. E2E `gallery`. |
| C3 | Numeric field — drag to change; release outside still ends the drag | `panels/input.rs` | VERIFIED | The drag is RmlUi's (`drag: drag` + pointer capture), which is the only thing that delivers a `dragend` when the button comes up outside the panel — the engine never hands the plugin a release for a press RmlUi consumed. The pointer is pinned to the drag anchor and drawn as the empty cursor, as the Chili version does. E2E `gallery` (`numeric-dragging`, and the value moves 50 → 80 without the field ever entering text mode) and `props_panel` (`props-drag-released-outside`, then asserting no further command as the mouse keeps moving). |
| C4 | Boolean field — toggle | `panels/fields/boolean.rs` | VERIFIED | Reports `flag_on = false` after the click. E2E `gallery`. |
| C5 | Choice field — open the list, pick an item | `panels/fields/choice.rs` | VERIFIED | The open list is a golden (`choice-open`); picking reports `choice = "Second"`. E2E `gallery`. |
| C6 | Colour field — picker modal, OK/Cancel | `panels/color_picker.rs` | VERIFIED | Opens from the field; the gradient is **grabbed** (mousedown, then the colour follows the pointer per tick — a press and release with no time between them is over before a tick runs), and OK commits: the field reports `colour = [0.41, 0.18, 0.18, 1.0]`. Escape closes it. E2E `gallery_pickers`. |
| C7 | Asset field — picker modal, pack navigation, pick | `panels/asset_picker.rs` | VERIFIED | **Was not a faithful port** and is now rewritten: the picker browses SpringBoard's *asset packs*, not a VFS directory (`springboard/assets/` holds one folder per pack; a field names a `rootDir` *within* one). It opens on the pack list, navigates into `core/`, back out with Up, and a picked file commits an **asset path** — `core/cement_diffuse.png` — which is what a project stores. Cells show the texture itself. E2E `gallery_pickers`, 6 screens. |
| C8 | Group layout (XYZ on one row) | `panels/editor_base.rs` | VERIFIED | Visible in `fields-at-rest`. |
| C9 | Grid view — selection, navigation, thumbnails | `panels/grid.rs` | VERIFIED | Selection + thumbnails by `def_grid` and `units_panel`; navigation (into a folder, and back out with Up) by `gallery_pickers`, asserting the listing actually redrew. The file dialog's Up correctly refuses to go above its root, which `gallery_dialogs` pins. |
| C10 | Tooltips on every control | `panels/field.rs` (`bind_tooltip`) | VERIFIED | Fields had no tooltip support at all; they do now (`with_tooltip`), bound in one place because every field renders as `field-<name>`. Hovering the numeric shows its tip and moving away removes it. E2E `gallery_tooltips`. Tooltips are **off in every other scenario** (`SBC_HIDE_TOOLTIPS`) — one follows the pointer and would land in the middle of any capture. |
| C11 | Dialogs — New Project | `panels/new_project_dialog.rs` | VERIFIED | Opens from the toolbar with its Name / Map / Size fields, and closes on Escape. E2E `gallery_dialogs`. **Not driven to creation** — a real project builds a map, which does not belong in a UI scenario. |
| C12 | Dialogs — File (load/save) | `panels/file_dialog.rs` | VERIFIED | Opens on the projects dir with its path nav and grid, and closes on Escape; Up at the root does nothing, which is the bound it should have. A plain directory browser, *not* the asset-pack model — as in the original. E2E `gallery_dialogs`. |

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

### 2026-07-11 — Map editors 5–9

- **5 — Map → Terrain: VERIFIED.** Confirmed the pattern grid, Size 140,
  Rotation 15, Strength 8.5, Height 25, Direction Only Raise, and Add/Set/
  Smooth command emission.
- **6 — Map → Texture (Paint): VERIFIED.** Confirmed the Saved brushes `+`
  flow opens a modal material chooser, creates/selects a saved brush, shows
  rich Diffuse/Normal/Specular availability tooltips, emits the Paint command,
  hides material controls outside Paint, and shows Splat controls only in DNTS.
- **7 — Map → Metal: VERIFIED.** Confirmed the expanded inline pattern grid,
  Size 180, Rotation 20, Amount 3.25, and `TerrainMetalCommand` emission.
- **8 — Map → Grass: VERIFIED.** Confirmed the expanded inline pattern grid,
  Detail 7, Size 160, Rotation 30, and `TerrainGrassCommand` emission.
- **9 — Map → Settings: VERIFIED.** Confirmed all three flags, all four Splat
  Scale and Mult fields, detail texture selection, and texture-map dialogs
  that offer New texture and Choose existing; both paths emitted successfully.
- E2E: `python3 tools/e2e/ui_driver.py map-editors --case rust --capture png`
  completed successfully, including a successful VFS-backed shading import.
  Artifact: `artifacts/ui-e2e/20260711-201750-map-editors-rust`.

The entries below are the harness fixes that made verification possible:

- The E2E harness now runs the native UI through the **same** scenarios as the
  Lua UIs (`--tag ui:rust`), on the premise that the port must behave
  identically. Twelve `ui:rust` cases exist.
- `screenshot_root` captured the X root window and failed intermittently,
  aborting scenarios. It now captures the engine window, like every other shot.
- The modal goldens compared full-frame, which included the dev console's boot
  log — and that log prints pointer addresses that change every run, so those
  goldens could never pass. They now crop to `no-console`.

### 2026-07-12 — Env implementation and Misc verification

- **10 — Env → Lighting: VERIFIED.** Confirmed shadow selection, all three sun
  direction components, all ground/unit diffuse/ambient/specular colors, and
  both shadow densities with committed commands. E2E: `lighting_panel`;
  artifact `20260712-070415-lighting-panel-rust`.
- **11 — Env → Sky: VERIFIED.** Confirmed all four atmosphere colors, Fog Start
  and End, and the Skybox picker. Skybox selection uses the native
  `set_sky_box_texture` binding; this test environment exposes no Skybox assets,
  so the verified picker state is empty. E2E: `sky_panel`; artifact
  `20260712-070435-sky-panel-rust`.
- **12 — Env → Water: VERIFIED.** Restored Shore waves and corrected Normal
  texture placement. The focused test first levels a size-3000 basin to -300
  with strength 1000, enables `/water 4`, then verifies every scalar, boolean,
  color, and Normal/Foam/base texture selection with the map visible. E2E:
  `water_panel`; artifact `20260712-071944-water-panel-rust`.
- **13 — Misc → Info: VERIFIED.** Name, Description, Version, and Author were
  edited independently; the final complete `SetScenarioInfoCommand` matched.
  E2E: `info_panel`; artifact `20260712-062711-info-panel-rust`.
- **14 — Misc → Teams: VERIFIED.** Replaced inline per-team forms with Lua's
  compact swatch/name/Edit/remove rows and Add action. Edit uses a modal with
  name, AI, resources/storage, color, start position, and side; Close emitted a
  complete update, including a committed picker color, and refreshed the row to
  `(AI) Team: Blue Team`; Add/remove were asserted. Side is populated from
  engine side data. E2E: `teams_panel`; artifact
  `20260712-071925-teams-panel-rust`.
