---
name: Review queue
description: Async review pipeline — items Claude has implemented that are waiting for user review / test / commit
---

# Review queue

Items Claude has finished implementing, awaiting human gates. Top of the list = oldest pending.

Each row has: link to the Rust file, the Lua file it replaces, a one-line description, and what to verify when testing. Claude appends; user moves items off as they're reviewed → tested → committed.

| # | Item | Files | State | What to test |
|--:|------|-------|-------|--------------|
| 3 | **Map settings** (slice 3). Sun direction + sun lighting, atmosphere (sky/fog), water params, map-rendering (splat scales/mults, void water/ground), and global-LOS — all Rust-only (`nativeCommandsOnly`). Each setter applies via `UnsyncedCtrl`/`SyncedCtrl` and snapshots the keys it touches via the matching `Gfx::Get*` for undo (map-rendering and global-LOS have no undo, matching their Lua). Water re-selects the current water mode after applying (`Display::GetWaterMode` + `Messages::SendCommands("water", N)`) so the renderer picks up new params — the native equivalent of Lua's `SendCommands('water '..GetWaterMode())`. Partial opts (editors send one key at a time). | New: [`map_settings/`](../../native/src/sbc/map_settings/)`commands/{set_sun_parameters,set_sun_lighting,set_atmosphere,set_water_params,set_map_rendering_params,set_global_los}_command.rs`, [`map_settings/tests/test_map_settings.rs`](../../native/src/sbc/map_settings/tests/test_map_settings.rs). Wiring: `mod map_settings;` in [sbc/mod.rs](../../native/src/sbc/mod.rs), flips in [command_manager.lua](../../scen_edit/command/command_manager.lua). **Lua command files unchanged** — only the dispatch flip. | review | `just test-integration map_settings` → 6 tests pass (each sets a value, reads it back via `Gfx::Get*`, undoes where applicable). In-editor: Lighting / Sky / Water / Terrain-settings editors → change sun direction, a ground color, fog color, a water param, splat scales → visible change; **Ctrl+Z** restores sun / lighting / atmosphere / water (map-rendering & global-LOS intentionally don't undo). |

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
