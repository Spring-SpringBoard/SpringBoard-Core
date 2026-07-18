---
name: Rust stable transfer plan
description: Order and rules for moving refactored rust-wip domains into rust-stable
---

# Rust stable transfer plan

## Transfer rule

Follow [conventions.md](conventions.md): do not cherry-pick WIP commits. Copy
only the files required for one reviewed domain into `rust-stable`, trim them to
the minimum coherent implementation, test in stable, add a review-queue entry,
and commit only after user authorization.

Every domain transfer includes its production code, focused Rust tests, E2E
scenario changes, and visually reviewed goldens. Goldens are never a final bulk
migration.

## Transfer order

1. **Compatibility spine**
   - Port flags and Rust-mode Lua self-disable rules.
   - Native/RmlUi lifecycle contract and explicit engine dependency inventory.
   - Reload/lifecycle integration coverage.

2. **Native runtime seam**
   - Minimal `SBC` integration changes.
   - Model-registry changes required by native producers.
   - Typed native command submission and command-history projection.

3. **Project IO foundation**
   - Extracted project paths plus save/load/export registrations.
   - No project editor UI in this slice.

4. **Generic native UI foundation**
   - Rml helpers, panel host, common theme, fields, grid, modal primitives, and
     input.
   - The control gallery is the acceptance test for this foundation.

5. **Chonsole**
   - Completion, persistent history, scrolling, mouse input, texture preview,
     and reload safety as one self-contained domain.

6. **Developer console and status strip**
   - Depends on Rml lifecycle and command history.
   - Transfer together so its undo/redo journal has one owner.

7. **World interaction foundation**
   - Neutral world renderer, selection, rectangle selection, drag/rotate, and
     ghost previews.

8. **Objects**
   - Typed commands and descriptors first.
   - Definitions/placement, then properties and collision as reviewable
     sub-slices.

9. **Terrain UI**
   - Heightmap, metal, and grass editors over the existing stable backend.
   - Reconcile backend deltas rather than overwrite stable implementations.

10. **Textures, then Map Settings**
    - Texture/material/brush ownership first.
    - Settings afterwards because optional shading textures depend on it.

11. **Environment**
    - Lighting, sky, and water under map-settings ownership.

12. **Teams, project info, and toolbar actions**
    - These intentionally come after the commands/models they invoke.

13. **Remaining domains**
    - Areas, triggers, variables, and compile/export pieces, each independently
      testable and reviewable.

## Per-slice exit criteria

Before a domain enters the review queue:

1. `just check` is green in stable.
2. Feature-local unit/integration tests are green.
3. The relevant native E2E target passes with zero warnings/errors/crashes.
4. Every changed golden has been visually inspected and recorded as
   `ai-reviewed`.
5. [verification.md](verification.md) has accurate `DONE`/`VERIFIED` evidence.
6. The review-queue row links the Rust files, replaced Lua code where relevant,
   a short in-game test recipe, risks, and CI status.

## Important constraints

- `rust-stable` already contains substantial backend work. Reconcile every
  transfer; do not blindly replace a stable directory with its WIP counterpart.
- Lua/RmlUi work is a separate historical product line. Only move Lua changes
  needed to prevent ownership collisions in Rust mode.
- Engine changes live outside this repository and need their own explicit
  compatibility inventory before a stable cutover.
