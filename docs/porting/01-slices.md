---
name: Porting slices — current state
description: Current Rust-port status and remaining project-lifecycle work
---

# Porting Slices

This file is now a current-state checklist. Historical slice notes live in git
history; this page should answer "what is left?" without making the reader dig
through old review context. Per-PR review context and test recipes live in
`review-queue.md`, not here.

## Slice status

Slices 0–9 cover the port; there is no slice 10. Everything is implemented —
slice 8 is the only one still in review.

| # | Slice | Status |
|--:|-------|--------|
| 0 | Command infrastructure | Done. Rust command registry, native bridge, undo/redo streaming, widget notify, bridge coverage, and native-command list sync are in stable. |
| 1 | Terrain | Done. Height/level/smooth/metal brush commands are Rust-only. |
| 2 | Heightmap | Done. Load/save/import/export are Rust-owned and use native IO jobs. Heightmap jobs are split by operation under `heightmap/jobs/`. |
| 3 | Map settings | Done. Sun, lighting, atmosphere, water, map-rendering, and global-LOS setters are Rust-only with native undo where supported. |
| 4 | Textures | Done. Diffuse/shading/terrain texture/cache/grass/DNTS paths are Rust-owned, including texture GL paths. |
| 5 | Objects | Done for the available integration fixtures. Feature and area paths are covered end-to-end; unit paths are ported but the smoke boot has no unit fixture yet, so the unit branch is not asserted as strongly as features. |
| 6 | Areas | Done. |
| 7 | Teams & diplomacy | Done. |
| 8 | Project lifecycle | **In review** (see `review-queue.md`). Metadata/scenario info and the Save/Load/Export/Copy/Reload/CompileMap commands are native; project IO uses a per-domain inventory registry (each domain registers its own save/load/export participant); grass/metal jobs are split by operation; async export is promise-driven via `executeNativeAsync(...)` with no Lua output-file polling. |
| 9 | Triggers + variables | Done. Rust owns CRUD; LuaRules keeps the runtime mirror needed by the existing trigger runtime. |

The native-command and project-IO design lives in
`docs/design/command-system.md`.
