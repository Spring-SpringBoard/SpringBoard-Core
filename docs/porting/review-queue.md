---
name: Review queue
description: Async review pipeline — items Claude has implemented that are waiting for user review / test / commit
---

# Review queue

Items Claude has finished implementing, awaiting human gates. Top of the list = oldest pending.

Each item is a one-line description and the steps to verify it in-game (read the diff for the code). Claude appends; user removes items as they're reviewed → tested → committed. Oldest first.

## Project lifecycle (slice 8) — native project save/load/export — *review*

`just test-all` runs the whole suite (unit + build + every integration test in
one engine boot) and must pass; it covers project model IO, model/map/texture
save-load-export, and the texture GL paths. To iterate on just this slice, filter
with `just test-integration project` (or `textures`). In-editor:

1. Make heavyweight project data changes: paint visible grass and metal
   patches, import a diffuse texture, and import or edit shading textures.
2. Save the project, reload it, and confirm those grass, metal, diffuse, and
   shading changes are still visible.
3. Export maps and confirm diffuse, shading, grass, and metal PNG outputs are
   written and reflect the saved project state.
4. Optional sanity check only: edit **Misc → Info** metadata and add the
   smallest possible model/variable/trigger data needed to prove the project
   model file still round-trips. Do not spend review time retesting object or
   team/player editing here; those belong to their own slices.

## Objects (slice 5) — units, features & areas add / remove / move / set-param — *review*

`just test-all` (or `just test-integration objects` to filter) → object tests
pass. In-editor:

1. Place a **unit** and a **feature**; drag to move, rotate, edit a property (health/mass) in the property window — each change shows in the engine.
2. Add an **area** (rect); drag to move and resize it.
3. **Ctrl+Z / Ctrl+Y** each of the above — undo restores, redo re-applies.
4. Place an **aircraft** unit and confirm its `crashing` state round-trips (only field not covered by automated tests).
5. **Identity probe:** add a unit and an area → undo → redo → **save + reload the project**; the objects and any trigger referencing them must survive.

## States

- **review** — Claude says implemented, lint + tests green; user hasn't read the code yet
- **tested** — user read it and ran it in-game; ready to commit
- **(removed from this file)** — committed; item deleted, phase doc updated to **done**

## Claude's flow

When finishing a port:

1. Update the matching phase doc — set status **review**.
2. Append an item here (a `##` section) with a short test recipe.
3. Move on to the next item (do not wait).

## User's flow

1. **Review**: read the diff. If happy, mark the item **tested** after testing it next.
2. **Test**: launch SBC, do the listed steps. If happy, tell Claude to commit.
3. **Commit**: Claude stages the right files, runs `git commit -m`, deletes the item, updates the phase doc to **done**.

If something fails at any gate: leave a note on the item, kick back to Claude (re-mark the phase-doc entry as **in progress**).

## Dependency rule

Don't stack co-dependent items here. If B needs A merged first, Claude either finishes A through **done** before starting B, or builds B so it works against both old and new versions of A.
