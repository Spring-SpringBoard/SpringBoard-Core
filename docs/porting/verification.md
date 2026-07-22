---
name: Native UI verification ledger
description: Evidence-backed TODO, DONE, VERIFIED, and user-approved status for native editor behaviour
---

# Native UI verification ledger

This is the current ledger for native Rust UI behaviour. It records current
evidence, not historical phase notes. A status must be lowered if a regression is
found.

## Stages

| Stage | Set by | Meaning |
|---|---|---|
| **TODO** | — | Missing or known incomplete. |
| **DONE** | Claude | Implemented, with code or focused automated-test evidence; not yet freshly driven and visually checked against the complete behaviour. |
| **VERIFIED** | Claude | Current E2E coverage exercised the complete behaviour and every resulting screen was inspected. |
| **APPROVED** | User only | User independently reviewed and accepted it. |

Rules:

- Claude may set TODO, DONE, and VERIFIED; only the user sets APPROVED.
- A rendered control is not DONE without an observable command/state assertion.
- VERIFIED requires all relevant controls/modes, current screenshots, and a
  written evidence summary below.
- New goldens are `ai-reviewed` only after visual inspection; user approval is
  separate.

Run a native target with:

```bash
just test-e2e <target> --tag ui:rust
```

## Editors

| # | Tab → Editor | Stage | Evidence / remaining proof |
|---|---|---|---|
| 1 | Objects → Units | DONE | Add/Brush, filters, grid, and placement are implemented. The generic UnitDef property API exposes `isBuilding`, `canSubmerge`, `waterline`, and `minWaterDepth`; `objects/tests/test_unit_def_params.rs` proves it. A deterministic unit fixture is still needed to exercise real unit definitions, thumbnails, placement, and filters end-to-end. |
| 2 | Objects → Features | DONE | Definitions, filters, search, thumbnails, and placement are implemented. `units_panel` proves feature placement; a fixture with a real wreck/unit is still needed before claiming complete Wreck/Terrain filter verification. |
| 3 | Objects → Properties | VERIFIED | Selection-driven fields, complete vector/table commits, map movement, and collision-field propagation. E2E `props_panel`. |
| 4 | Objects → Collision | VERIFIED | Visibility, type/axis, scale/offset/center/aim, radius/height, linked cylinder scale, and blocking fields. E2E `props_panel` and `collision`. |
| 5 | Map → Terrain | VERIFIED | Pattern, size, rotation, strength, height, direction, Add/Set/Smooth, textured preview, and a stationary held stroke. E2E `heightmap`, `map-editors`, `pattern-preview`, `terrain-stationary-hold`. |
| 6 | Map → Texture | VERIFIED | Saved brushes, material dialog, Paint/Filter/DNTS/Void, and splat controls. Rust is the sole owner of texture paint, cache, stroke close, undo, and redo; native GL and Lua command-bridge tests cover that ownership contract. E2E `texture-paint`, `map-editors`. |
| 7 | Map → Metal | VERIFIED | Pattern, size, rotation, amount, and painting. E2E `map-editors`, `metal-paint`. |
| 8 | Map → Grass | VERIFIED | Pattern, detail, size, rotation, and painting. E2E `map-editors`, `grass-paint`. |
| 9 | Map → Settings | VERIFIED | Rendering flags, splat fields, detail texture, and New/Existing texture paths. E2E `map-editors`, `settings-panel`. |
| 10 | Env → Lighting | VERIFIED | Shadow mode, direction, six colours, and densities. E2E `lighting-panel`. |
| 11 | Env → Sky | VERIFIED | Atmosphere colours, fog bounds, and skybox picker. E2E `sky-panel`. |
| 12 | Env → Water | VERIFIED | Scalars, booleans, colours, Normal/Foam/base textures, and visible water. E2E `water-panel`. |
| 13 | Misc → Info | VERIFIED | Name, description, version, and author commit a complete scenario record. E2E `info-panel`. |
| 14 | Misc → Teams | VERIFIED | Roster, add/remove, edit modal, resources, colour, position, side, and row refresh. E2E `teams-panel`. |

## Editor behaviour

| # | Behaviour | Stage | Evidence / remaining proof |
|---|---|---|---|
| 15 | Click selection | VERIFIED | Feature selection, marker, and property editing. E2E `deselect`, `props_panel`. |
| 16 | Shift-click multi-select toggle | VERIFIED | E2E `selection-drag` (2026-07-18): a plain click selected one tree, Shift-click visibly selected both, and the two-object property edit emitted exactly two position commands. |
| 17 | Rectangle selection | VERIFIED | Dragged rectangle, final selection, and editable selected feature. E2E `selection`. |
| 18 | Empty click and Escape clear selection | VERIFIED | Includes clearing after an empty rectangle. E2E `deselect`. |
| 19 | Feature selection marker | VERIFIED | Green, feature-only, and drawn under units. E2E `deselect`. |
| 20 | Object drag/move | VERIFIED | E2E `selection-drag` (2026-07-18): inspected two textured drag ghosts and final moved pair; release emitted exactly two non-preview position commands. |
| 21 | Ctrl-drag rotation | VERIFIED | Multi-selection, ghosts, one undo group, and changed positions. E2E `rotation`. |
| 22 | Set placement preview | VERIFIED | Textured model ghost and amount preview. E2E `units_panel`. |
| 23 | Brush/scatter placement | VERIFIED | Scatter preview, placement density, and shared wheel/panel size. E2E `brush-size`. |
| 24 | Object delete | VERIFIED | E2E `object-actions` (2026-07-18): Delete removed a live selected tree and Undo restored visible map pixels. |
| 25a | Copy / Paste | VERIFIED | E2E `object-actions` (2026-07-18): copy then paste emitted the grouped native command and visibly added the feature at the cursor hit. |
| 25b | Cut | VERIFIED | E2E `object-actions` (2026-07-18): Cut removed the selected feature; inspected Undo/Redo screens restored and removed it again. |
| 26 | Undo / Redo | VERIFIED | E2E `object-actions` (2026-07-18): Cut, Redo, and Delete each changed live map pixels; Undo/Redo commands and each inverse result were asserted. |
| 27 | Toolbar actions | DONE | E2E `toolbar-actions` (2026-07-18) freshly exercised and visually reviewed every toolbar icon: New Project, Load, Import, Save, Save As, Export, Copy, Paste, and Cut. Project icons were deliberately cancelled after their correctly configured dialogs opened; fixture-backed acceptance of each file operation remains before this becomes VERIFIED. |
| 36b | Cursor tooltip | VERIFIED | Empty-ground suppression, feature/unit content, and map hover. E2E `cursortip`. |
| 37 | Pattern brush preview | VERIFIED | Fresh E2E `pattern-preview` (2026-07-18): a Terrain/Add state without a pattern had no footprint; choosing the pattern produced the inspected textured ground projection beneath the same cursor. |
| 38 | Ray-trace agreement | TODO | Existing selection tests do not prove click, drag, and preview resolve the same point. |
| 39 | Developer console | VERIFIED | Fresh E2E `native-dev-console` and `native-dev-console-copy` (2026-07-18): reviewed cleared/visible/hidden/Problems screens, live status controls, multiline selection, Ctrl+C, and Ctrl+A copy ownership. |
| 40 | Chonsole | DONE | Dedicated scenarios cover editing, completion cycling, mouse hover/click, scroll, texture/rule completion, persistence, and native reload. Re-run and inspect them as one current verification pass. |
| 41 | Status strip | DONE | Metrics, command journal, undo/redo/clear controls, and a status golden are implemented. Re-run with developer console and inspect layout/current metrics. |

## Shared controls and dialogs

| Control | Stage | Evidence |
|---|---|---|
| String field | VERIFIED | `gallery` command assertion. |
| Numeric text edit and drag | VERIFIED | `gallery`, `props-panel`, including release outside. |
| Boolean/toggle field | VERIFIED | `gallery` command assertion and control golden. |
| Choice field | VERIFIED | `gallery` open-list golden and selected value assertion. |
| Colour picker | VERIFIED | `gallery-pickers`: drag, OK, Cancel, and command value. |
| Asset picker | VERIFIED | `gallery-pickers`: pack navigation, selection, and stored asset path. |
| Group layout | VERIFIED | `gallery` golden. |
| Grid view | VERIFIED | Definition grid plus asset/file navigation scenarios. |
| Control tooltips | VERIFIED | `gallery-tooltips`. |
| New Project dialog | VERIFIED | `gallery-dialogs`: open, fields, Escape. |
| File dialog | VERIFIED | `gallery-dialogs`: root, navigation, and Escape. |

## Verification work now required

The next verification pass must target every non-VERIFIED implemented item:

1. Add or enable a deterministic unit fixture; verify Units and real wreck
   filtering.
2. Add a fixture-backed acceptance pass for each project file toolbar operation.
3. Run and inspect current developer-console, status-strip, and Chonsole
   scenarios before promoting rows 39–41.
4. Leave rows 37 and 38 TODO until their missing behaviour is implemented and
   testable.
