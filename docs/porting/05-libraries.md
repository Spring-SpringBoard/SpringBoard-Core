---
name: Phase 7 — Libraries
description: Remove obsolete Lua + JS libraries under libs_sb
---

# Phase 7 — Libraries

Once Phases 1–6 are far enough along that we know what's still consumed, deal
with obsolete dependencies under [libs_sb/](../../libs_sb/).

Goal: same as the rest — leave only the bare minimum Lua needed for Spring to load the project.

## libs_sb inventory

| Library | Fate | Notes |
|---------|------|-------|
| [chili](../../libs_sb/chiliui/) | drop | UI framework — replaced by RmlUi in Phase 4 |
| [chilifx](../../libs_sb/chilifx/) | reimplement in Rust | Effects/animations; design in Rust |
| [chotify](../../libs_sb/chotify/) | reimplement in Rust | Notifications |
| [chonsole](../../libs_sb/chonsole/) | reimplement in Rust | Console; partially superseded by `dbg_dev_console_rmlui` |
| [i18n](../../libs_sb/i18n/) | reimplement in Rust | Localisation. Pick a Rust-friendly format (Fluent, gettext, or simple key-value JSON) |
| [s11n](../../libs_sb/s11n/) | drop / replace with serde | Lua serialization — serde covers this in Rust |
| [lcs](../../libs_sb/lcs/) | drop | Not needed in Rust |
| springmon | dropped | Removed with the launcher connector; live-reload/watch-file support is no longer part of SBC. |
| spring-launcher connector | dropped | Export/import/compile/file operations moved to Rust/native IO; open-file/upload-log support removed. |
| [utils](../../libs_sb/utils/) | reimplement in Rust | General-purpose Lua helpers; port what's still used |
| [kernel](../../libs_sb/kernel/) | TBD | Inspect — probably partly drop, partly port |
| [json.lua, MessagePack.lua, savetable.lua](../../libs_sb/) | drop | One-file Lua libs; serde + bincode/msgpack-rust handle equivalents |

## Launcher Connector

The in-engine editor no longer depends on the JS launcher connector. The command
features SBC depended on were either moved to Rust/native IO (`CompileMap`,
heightmap import/export, texture/map exports, recursive delete, archive zip) or
removed from the UI (`OpenFile`, upload-log, springmon watch-file integration).

## chonsole

The console implementation is controlled by [port_flags.json](../../port_flags.json):
set `"chonsole": "rust"` to use the native console, or `"chonsole": "lua"` to
leave the legacy Lua/Chili loader active. Both sides read the flag during load,
so this is a restart-time switch rather than a live toggle.

The native replacement lives under
[native/src/sbc/chonsole/](../../native/src/sbc/chonsole/) and is fully native:
Rust owns the command model, prefix-filtered history, fuzzy completion, RmlUi
document, draw callback, and input callbacks. It deliberately does not port
arbitrary Lua execution or the old Lua extension loader; unknown slash commands
are forwarded to the Spring engine, while chat and basic native commands are
handled directly.

## utils

[libs_sb/utils/](../../libs_sb/utils/) is small but pulled in many places. Audit which functions are still called from Lua after Phase 6, then port the survivors. Most of it is probably string/table helpers that Rust has natively.

## Dependency on Phase 6

Phase 6 (final Lua cleanup) and Phase 7 overlap: dropping libraries falls out naturally as their last Lua consumer is removed. So in practice these get done together rather than sequentially.
