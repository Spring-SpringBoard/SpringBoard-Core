---
name: Review queue
description: Async review pipeline — items Claude has implemented that are waiting for user review / test / commit
---

# Review queue

Items Claude has finished implementing, awaiting human gates. Top of the list = oldest pending.

Each row has: link to the Rust file, the Lua file it replaces, a one-line description, and what to verify when testing. Claude appends; user moves items off as they're reviewed → tested → committed.

| # | Item | Files | State | What to test |
|--:|------|-------|-------|--------------|
| 2 | **Heightmap load + image import/export** (slice 2). Whole-map load + 16-bit-greyscale PNG import/export on the background IO worker, all Rust-only (`nativeCommandsOnly`). Load reads the `.data` file (LE `f32`) by **path** — the path crosses the bridge, not the bytes. Import/export replace the spring-launcher round-trip. Lands the command IO seam: `Context::submit_io` → drained into the worker after execute → `SBC::drain_io`; `wait_for_io`/`wait_for_file` test helpers. | New: [`heightmap/commands/`](../../native/src/sbc/heightmap/commands/)`{load_map,import_heightmap,export_heightmap}_command.rs`, [`heightmap/model/heightmap_io.rs`](../../native/src/sbc/heightmap/model/heightmap_io.rs). Seam: [context.rs](../../native/src/sbc/command_system/context.rs), [sbc.rs](../../native/src/sbc/sbc.rs), [tests_api.rs](../../native/src/sbc/tests/tests_api.rs), `image` dep. Lua: [load_map_command.lua](../../scen_edit/command/load_map_command.lua) (path, not bytes), [load_project_command_widget.lua](../../scen_edit/command/project/load_project_command_widget.lua) (passes the path), flip in [command_manager.lua](../../scen_edit/command/command_manager.lua). | review | `cd tools/smoke && uv run pytest` → `heightmap_load` + `heightmap_import` + `heightmap_roundtrip` pass (load applies heights from a written `.data`; import/export at 16-bit tolerance). In-editor (now Rust-only): **load a saved project** → terrain restores; import a PNG → terrain matches; export → 16-bit PNG that re-imports. Export reads **live** engine heights (Lua read a saved file). |

## States

- **review** — Claude says implemented, lint + tests green; user hasn't read the code yet
- **tested** — user read it and ran it in-game; ready to commit
- **(removed from this file)** — committed; row deleted, phase doc updated to **done**

## Claude's flow

When finishing a port:

1. Update the matching phase doc — set status **review**.
2. Append a row here with a short test recipe.
3. Move on to the next item (do not wait).

## User's flow

1. **Review**: read the linked Rust file. If happy, mark row **tested** after testing it next.
2. **Test**: launch SBC, do the steps in "What to test". If happy, tell Claude to commit.
3. **Commit**: Claude stages the right files, runs `git commit -m`, deletes the row, updates the phase doc to **done**.

If something fails at any gate: leave a note in the row, kick back to Claude (re-mark the phase-doc entry as **in progress**).

## Dependency rule

Don't stack co-dependent items here. If B needs A merged first, Claude either finishes A through **done** before starting B, or builds B so it works against both old and new versions of A.
