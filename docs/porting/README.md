---
name: Porting SBC from Lua to Rust
description: Top-level dashboard for the Lua → Rust + RmlUi porting effort
---

# Porting SBC: Lua → Rust + RmlUi

Iterative port. The app must run at every commit. Lua and Rust live side-by-side per area until the Rust path is reviewed and manually tested, then dispatch flips.

End state: almost no Lua left — only what Spring needs to register the project and bootstrap the native library. RmlUi stays for rendering; the logic behind it is driven from Rust.

No deadline.

## Status

| Phase | Area | Status | Doc |
|------:|------|--------|-----|
| 0 | Baseline (native crate + CI + smoke + Lua→Rust bridge) | todo | — |
| 1 | Commands (78 files) | todo | [01-commands.md](01-commands.md) |
| 2 | State (21 files) | todo | [02-state.md](02-state.md) |
| 3 | Model (24 files) | todo | [03-model.md](03-model.md) |
| 4 | View — Chili → RmlUi (Lua-side first) | in progress (pre-port) | [04-view.md](04-view.md) |
| 5 | View logic → Rust (drive RmlUi from native) | todo | [05-view-rust.md](05-view-rust.md) |
| 6 | Final cleanup (delete remaining Lua) | todo | [06-cleanup.md](06-cleanup.md) |
| 7 | Libraries (libs_sb + spring-launcher) | todo | [07-libraries.md](07-libraries.md) |

Phase 4 is in progress independently of the Rust port (some Chili→RmlUi work landed earlier).

Pending review items: [review-queue.md](review-queue.md). Rules: [conventions.md](conventions.md).

## Where things live

- Lua source: [scen_edit/](../../scen_edit/)
- Rust source: will live under `native/` (Phase 0)
- Engine API (sibling repo): `spring-bar/rust/crates/spring-native`

## Status terms

Used in phase docs and the review queue:

- **todo** — not started
- **in progress** — Claude is working on it
- **review** — Claude says done; user hasn't read the code yet
- **tested** — user read it and ran it in-game; ready to commit
- **done** — committed; Lua path may be removed

Only the user marks anything **done**, and only after manual test passes.
