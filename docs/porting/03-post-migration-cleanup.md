---
name: Post-migration cleanup
description: Lua, library, launcher, and documentation cleanup after Rust domains are stable and approved
---

# Post-migration cleanup

## When this starts

This is deliberately deferred. Start only once the relevant Rust domains are
stable, user-approved, and no longer rely on their Lua implementation for
runtime ownership. Do not delete a Lua path merely because an equivalent Rust
file exists in WIP.

## Goal

Leave only the Lua files Spring structurally requires to discover the project,
bootstrap the native module, and expose mandatory metadata. Rust owns editor
logic, commands, persistence, rendering decisions, and UI behaviour.

## Audit procedure

For each candidate Lua file or library:

1. Find all references, including VFS includes, widget/gadget discovery, and
   dynamic command registration.
2. Identify the Rust owner and the stable commit that transferred it.
3. Prove the Rust path owns runtime execution in the relevant mode.
4. Delete the Lua file and its now-unused assets/configuration.
5. Run the feature tests plus a native boot with zero warnings/errors/crashes.
6. Record the removal in the review queue and update the project README.

## Lua/bootstrap boundary

The final Lua footprint may include:

- Spring-discovered widget/gadget entry points;
- the minimal native-library loader and callback forwarding;
- Spring-required metadata such as `modinfo.lua` or game data;
- compatibility shims that remain required by the engine.

Everything else must be justified by a live dependency or removed.

## Library audit

Audit `libs_sb/` only after its consumers are gone. Expected candidates include
Chili, ChiliFX, Chotify, Chonsole, i18n, s11n, lcs, utility helpers, kernel, and
the old launcher connector. Do not assign a library a fate in advance: record
its consumers, replacement, deletion commit, and test evidence.

The old launcher connector remains removed unless a user-approved feature
requires it again. Native IO/export/compile paths must be independently tested
before deleting their Lua counterparts.

## Final checklist

- Audit `scen_edit/`, `LuaUI/`, `LuaRules/`, and `libs_sb/` for live references.
- Remove obsolete Lua files, RmlUi documents, assets, and configuration together.
- Remove dead native compatibility code left only for the parallel implementation.
- Update repository documentation to describe the final architecture.
- Confirm `just lint` is clean.
- Boot the native application and run the final relevant E2E suite with zero
  warnings, errors, or crashes.
- Count remaining Lua files and document why each one remains.
