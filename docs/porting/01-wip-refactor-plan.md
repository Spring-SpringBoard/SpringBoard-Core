---
name: Rust WIP refactor plan
description: Remaining structural work in rust-wip before selectively moving domains into rust-stable
---

# Rust WIP refactor plan

`rust-wip` is functionally broad but developed as a fast, exploratory workspace.
Before work transfers into `rust-stable`, its ownership boundaries and module
structure must match [conventions.md](conventions.md), so the stable branch
receives small, reviewable domain slices rather than architectural cleanup.

## Done

- Feature UI is feature-owned (`<feature>/ui/`, each editor split into
  `model` / `layout` / `behavior`); the old `panels/editors/` is gone.
- `ModelShader` extracted to `sbc/render/`; `states` no longer imports panel UI.
- `PanelManager` decomposed into `EditorSlot` / `FieldSession` / `ModalStack` /
  `ActionDispatcher` / `BrushSync`; the wide `Editor` trait is implemented once
  by the generic `Runtime<B>`.
- Shared theme split into `panels/theme/*.rcss`.
- Concrete UI moved out of `panels/`: the dev editor → `dev/`, the new-project
  dialog → `project/`, def thumbnails → `objects/`. Reusable pieces grouped
  under `panels/{controls,dialogs,cursor,fields,runtime,theme}`.
- Duplicate model-factory registration now panics with the model's type name,
  as duplicate command registration already does (`Models::build`).
- Texture material discovery is feature-owned: `Material` / `list_materials`
  moved to `textures/materials.rs`, reading the VFS directly. The VFS listing
  helpers moved out of the grid to a neutral `sbc/vfs.rs`, so the domain no
  longer depends on UI code.
- The `E2ERun` monolith is split by concern into mixins (`run_session`,
  `run_input`, `run_capture`, `run_pixels`, `run_commands`, `run_report`), each
  under ~300 lines; `runner.py` is now just the composition and instance state.
  Scenarios still `from runner import E2ERun` and call the same methods.

## Remaining

### Objects boundary

Properties and Collision still duplicate selection projection and object-field
mapping. Extract a shared `objects/ui/selection.rs` both project through. Also
TODO #1: replace the generic JSON Area/Feature/Unit object commands with
concrete typed commands, and cache static object-field descriptors.

### Split project IO from the Project feature

Finish extracting project paths + save/load/export registrations into a neutral
project-IO/workspace module (`io_registries`, `paths` exist but still sit inside
`project/`). Scenario metadata, archive export, reload, map info, and the
project editor stay in `project/`. This is TODO #16; it stops each saving
feature depending on the whole Project feature.

### Finish the panels/ toolkit

- `brush.rs` is misnamed: it is the brush-editor action-strip UI plus a couple
  of asset-field helpers, not "a brush". Rename to reflect that it is UI (e.g. an
  action-strip control) — it must stay in the UI layer, because it renders RML
  and moving it out reintroduces the `states → panel` dependency.
- `modal_stack` enumerates concrete dialogs as fields
  (`new_project: NewProjectDialog`). If it is meant to be the app-wide modal
  concept, dialogs should self-register (inventory, like editors) rather than be
  listed. Also review what `modal_stack` actually does.
- `tokens.rcss`: a single source for colours/spacing/sizes needs build-time
  substitution, because RmlUi's RCSS has no variables.

## Do not rewrite first

- Chonsole (catalog/completion/input/history/model/views) and the developer
  console (actions/log/metrics/manager/view) are already sensibly divided;
  transfer each as one domain after shared RmlUi lifecycle work.
- Do not replace the command system wholesale; reconcile only its required WIP
  delta against stable.
