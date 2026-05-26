---
name: Phase 7 — Libraries (libs_sb + spring-launcher)
description: Reimplement / drop the Lua + JS libraries under libs_sb/ and the spring-launcher
---

# Phase 7 — Libraries

Once Phases 1–6 are far enough along that we know what's still consumed, deal with the dependencies under [libs_sb/](../../libs_sb/) and the JS-based [spring-launcher](../../libs_sb/spring-launcher/).

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
| [springmon](../../libs_sb/springmon/) | maybe drop | We have other Rust monitors; check what's still wired |
| [spring-launcher](../../libs_sb/spring-launcher/) | reimplement in Rust | **JS launcher → Rust**. Significant. See below. |
| [utils](../../libs_sb/utils/) | reimplement in Rust | General-purpose Lua helpers; port what's still used |
| [kernel](../../libs_sb/kernel/) | TBD | Inspect — probably partly drop, partly port |
| [json.lua, MessagePack.lua, savetable.lua](../../libs_sb/) | drop | One-file Lua libs; serde + bincode/msgpack-rust handle equivalents |

## spring-launcher (Rust rewrite)

The Electron/JS launcher is its own large project — separate codebase, separate UI, separate update mechanism. Replacing it in Rust is genuinely a major undertaking and should not be conflated with the SBC port.

Open questions to resolve before opening this phase:
- Target framework? (tauri, iced, egui, slint — or RmlUi too?)
- Reuse the Rust engine bindings from the port, or keep launcher fully independent?
- Update channel handling — does the new launcher self-update?
- Cross-platform: Linux + Windows at minimum, Mac if feasible

This phase doesn't open until the SBC core port (1–6) is at least mostly done. Otherwise we'd be rewriting two big systems in parallel without either being usable.

## utils

[libs_sb/utils/](../../libs_sb/utils/) is small but pulled in many places. Audit which functions are still called from Lua after Phase 6, then port the survivors. Most of it is probably string/table helpers that Rust has natively.

## Dependency on Phase 6

Phase 6 (final Lua cleanup) and Phase 7 overlap: dropping libraries falls out naturally as their last Lua consumer is removed. So in practice these get done together rather than sequentially.
