---
name: Review queue
description: Async review pipeline — items Claude has implemented that are waiting for user review / test / commit
---

# Review queue

Items Claude has finished implementing, awaiting human gates. Top of the list = oldest pending.

Each row has: link to the Rust file, the Lua file it replaces, a one-line description, and what to verify when testing. Claude appends; user moves items off as they're reviewed → tested → committed.

| # | Item | Files | State | What to test |
|--:|------|-------|-------|--------------|
| 1 | Slice 1 — Terrain brushes (shape / level / smooth / metal) ported to Rust, flipped to Rust-only. Also lands the feature-agnostic IO-worker shell (boxed-job seam) + in-engine test harness as common infra. | Rust: [terrain_shape_modify_command.rs](../../native/src/sbc/commands/heightmap/terrain_shape_modify_command.rs), [terrain_level_command.rs](../../native/src/sbc/commands/heightmap/terrain_level_command.rs), [terrain_smooth_command.rs](../../native/src/sbc/commands/heightmap/terrain_smooth_command.rs), [terrain_metal_command.rs](../../native/src/sbc/commands/heightmap/terrain_metal_command.rs), [set_heightmap_brush_command.rs](../../native/src/sbc/commands/set_heightmap_brush_command.rs), [brush_modify.rs](../../native/src/sbc/commands/heightmap/brush_modify.rs), [brush_filter_generator.rs](../../native/src/sbc/commands/heightmap/brush_filter_generator.rs), [terrain_manager.rs](../../native/src/sbc/commands/heightmap/terrain_manager.rs), [io/io_api.rs](../../native/src/sbc/io/io_api.rs), [io/worker.rs](../../native/src/sbc/io/worker.rs), [tests/tests_api.rs](../../native/src/sbc/tests/tests_api.rs). Lua: [command_manager.lua](../../scen_edit/command/command_manager.lua) (allowlist), [widget.lua](../../scen_edit/widget.lua) (poll driver) — replacing the Lua brushes in [abstract_terrain_modify_command.lua](../../scen_edit/command/abstract_terrain_modify_command.lua) + the four `terrain_*_command.lua`. | review | 1. Raise/lower brush: stamp flat ground — terrain rises and **visibly moves**; undo restores; redo re-applies. 2. Level: set a target height, stamp — area flattens; undo/redo. 3. Smooth: stamp rough terrain — smooths; undo/redo. 4. Metal: stamp — metal spots appear; undo/redo. 5. **Drag** one continuous stroke, undo once — the whole stroke reverts as a unit, and the infolog has **no** `streaming_commands` errors. Automated: `cd tools/smoke && uv run pytest` → 9 passed. |

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
