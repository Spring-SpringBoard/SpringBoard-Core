---
name: Phase 6 — Final cleanup
description: Delete remaining Lua, keep only the Spring entry stub
---

# Phase 6 — Final cleanup

After Phases 1–5: all logic is in Rust. This phase removes everything else.

## What stays in Lua

Only what's structurally required to be picked up by the Spring engine:

- The widget/gadget entry files Spring looks for (e.g. `LuaUI/widgets/*.lua` stubs)
- A minimal loader that boots the native library and forwards engine callbacks into it
- Whatever metadata files (`modinfo.lua`, `gamedata/*.lua` if any) the engine requires

Everything else — `scen_edit/`, the libraries under `libs_sb/` that we no longer use, etc. — gets deleted.

## Checklist

- todo: Audit `scen_edit/` — what is still referenced from the Lua entry stub?
- todo: Delete unreferenced Lua files
- todo: Audit [libs_sb/](../../libs_sb/) — drop libraries no longer used (`chili`, `s11n`, `lcs`, `chotify`, `chonsole`, `i18n` — likely most of them once view + model are Rust)
- todo: Audit [LuaUI/](../../LuaUI/) — reduce to the minimum bootstrap
- todo: Update [README.md](../../README.md) to reflect the new architecture
- todo: Confirm `cloc scen_edit/` shows roughly zero Lua

## Exit criteria

`find . -name "*.lua" | wc -l` is small (entry stubs + Spring-required files only). `just lint` clean. App still works end-to-end.
