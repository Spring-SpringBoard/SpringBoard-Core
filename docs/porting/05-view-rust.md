---
name: Phase 5 — View logic → Rust
description: Drive RmlUi from native code instead of Lua handlers
---

# Phase 5 — View logic → Rust

After Phase 4: all UI is RmlUi, but the event handlers, data binding, and view-model code still live in Lua. This phase moves that logic into Rust so RmlUi is driven from native — no Lua needed.

Prerequisites:
- Phase 4 complete (no Chili left)
- Engine API exposes whatever RmlUi bindings native needs (document context, event listeners, data sources)

## Approach

Per RmlUi document, in this order:

1. Pick a self-contained panel (start with `status_window` — small, isolated).
2. Re-implement its handlers + view-model in Rust.
3. Switch the loader to register the Rust handlers instead of Lua ones.
4. Delete the Lua handler file.

Floating windows first (smallest surface), then dialogs, then the main editor panels.

## Inventory

Filled in once Phase 4 is far enough along that we know which Lua files survive into this phase.

Likely starting points (in order):

- `status_window` — small, isolated
- `command_window`
- `control_buttons`
- `top_left_menu`
- *(others — fill in as Phase 4 progresses)*

## Exit criteria

No Lua file in `scen_edit/view/` contains business logic. Anything that remains is a thin shim or has been deleted.
