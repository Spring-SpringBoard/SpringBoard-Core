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
| 0 | Baseline (native crate + CI + integration tests + Lua→Rust bridge) | partly done | — |
| 1 | Command execution slices — model + commands ported together, one feature at a time | in progress | [01-slices.md](01-slices.md) |
| 2 | View — Chili → RmlUi (Lua-side first) | in progress (pre-port) | [02-view.md](02-view.md), [status](02-view-status.md) |
| 3 | View logic → Rust (drive RmlUi from native) | in progress | [03-view-rust.md](03-view-rust.md), [issues](03-view-rust-issues.md) |
| 4 | Final cleanup (delete remaining Lua) | todo | [04-cleanup.md](04-cleanup.md) |
| 5 | Libraries (libs_sb + spring-launcher) | todo | [05-libraries.md](05-libraries.md) |

Phase 1 ports the model and command layers together in slices (one feature end-to-end at a time) instead of layer-by-layer. State (editor state classes like brush/drag/selection) is UI-side and lives under Phase 2/3.

Phase 2 is in progress independently of the Rust port (some Chili→RmlUi work landed earlier).

Phase 3 is the current focus: the native UI. What the user has found broken while
testing it lives in [user-testing-issues.md](user-testing-issues.md) — that is the
working list, and only the user marks a line `[DONE]`.

Pending review items: [review-queue.md](review-queue.md). Rules: [conventions.md](conventions.md). Commands: [commands.md](../commands.md). Deferred improvements: [todo.md](todo.md).

## Testing

The E2E harness (`tools/e2e/`) drives the real editor window and screenshots it.
The native UI reuses the *same* scenarios as the Lua UIs, since it is meant to
behave identically:

```bash
python3 tools/e2e/ui_driver.py <target> --tag ui:rust
```

**[verification.md](verification.md) is the ledger**: every editor tab and every
editor behaviour, each at TODO → DONE → VERIFIED → APPROVED. Claude sets the
first three; only the user sets APPROVED.

See [02-view-status.md](02-view-status.md) for targets and the golden workflow.

## Design docs

Living documents describing how subsystems work (outlast the slice docs, which
are purged once a slice lands):

- [Command system](../design/command-system.md) — how editor actions become commands and execute
- [Async IO](../design/async-io.md) — running file IO / image work off the engine thread

## Where things live

- Lua source: [scen_edit/](../../scen_edit/)
- Rust source: [native/](../../native/)
- Engine API (sibling repo): `spring-bar/rust/crates/spring-native`

## Status terms

Used in phase docs and the review queue:

- **todo** — not started
- **in progress** — Claude is working on it
- **review** — Claude says done; user hasn't read the code yet
- **tested** — user read it and ran it in-game; ready to commit
- **done** — committed; Lua path may be removed

Only the user marks anything **done**, and only after manual test passes.
