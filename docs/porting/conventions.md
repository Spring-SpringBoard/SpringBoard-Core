---
name: Porting conventions
description: How the Lua → Rust port is carried out — process, structure, quality
---

# Conventions

## Two-directory workflow (wip + stable)

The work happens in **two side-by-side directories**, both checkouts of this repo:

- **wip** — `/home/gajop/projects/spring-projects/SBC.sdd` (this dir, branch `rust`). Claude works here. Permanent dirty tree, fat and growing. **Claude never commits here, ever.** Loses no work because nothing gets trimmed away.
- **stable** — `/home/gajop/worktrees/SBC.sdd/SBC-rust-stable.sdd` (git worktree, branch `SBC-rust-stable.sdd`). User reviews and tests here. Only the slimmed-down, review-ready slice exists here. All commits happen here. User pushes from here.

Both share the same `.git`. Sync runs two directions:

- **wip → stable**: `cp`, one file at a time. The normal forward flow — a finished slice is copied into stable and trimmed there.
- **stable → wip**: `git rebase`. Review-time edits (rename, reorder, fix) are committed in stable, and wip rebases `rust` onto `SBC-rust-stable.sdd` to absorb them. Never `cp` backwards — the rebase is what carries reviewed edits home, so they survive the next forward `cp`.

### The loop

For each review item:

1. **Build & test in wip** — full fat tree. `cargo check`, `cargo test`, and the integration tests (`uv run pytest` in `tools/smoke/`).
2. **Copy → trim in stable** — `cp` the files in (one at a time, no wildcards), trim to the minimal version for this slice. Never trim in wip.
3. **Test in stable** — same suite, run inside stable.
4. **Review** — add a row to [review-queue.md](review-queue.md). User reviews → tests → authorizes; the user may edit files in stable during review. Claude commits in stable, user pushes.
5. **Rebase wip onto stable** — before the next slice, see [Rebasing wip onto stable](#rebasing-wip-onto-stable).

### Rules

- **Never commit in wip.** All commits happen in stable; wip only rebases onto stable's history.
- **Never trim in wip.** wip stays fat — the full version is the safety net.
- **Forward (wip → stable) is `cp`; back (stable → wip) is `rebase`.** No `git mv` / `cherry-pick` between dirs (cherry-pick drags along the rest of the commit; we want slice-sized control).
- **Test on both sides every slice** — even a no-op scaffolding slice, to prove the native lib loads and inits.

### Rebasing wip onto stable

wip has no commits of its own, just a dirty tree, so park it across the rebase:

1. `git stash --include-untracked`
2. `git rebase SBC-rust-stable.sdd`
3. `git stash pop`, then resolve conflicts toward stable's reviewed version.

Between slices only, never mid-slice. If the tree won't stash cleanly, finish or discard the local change first.

## Process

**Parallel implementations.** Lua stays the active path until the Rust replacement is reviewed and manually tested. Both impls live side-by-side; the dispatch layer chooses which runs. Don't delete Lua before Rust is verified.

**File-by-file.** One Lua file → one Rust module. Names align: `add_variable_command.lua` → `add_variable_command.rs`.

**Two human gates** after Claude says "implemented":

1. **Review** — user reads the Rust code.
2. **Manual test** — user runs SBC, exercises the feature.

Claude does lint (`cargo fmt`, `cargo clippy -D warnings`), unit tests, and the integration tests. Claude never marks anything done.

**Commits.** All commits happen in **stable**, never in wip. Claude runs `git commit -m` in stable, only after user authorizes. Small commits: one port (or a small batch of related ports) per commit. The dispatch flip can ride along or come in a follow-up.

## Async review pipeline

User availability is bursty. Claude works ahead:

1. Implement several items in a row. Each is self-contained — separate files, independent dispatch toggles, no cross-coupling.
2. Each lands in [review-queue.md](review-queue.md), oldest at top.
3. User reviews when available (sometimes in batches), tests, then tells Claude to commit.
4. Claude keeps working — doesn't wait for the queue to drain.

**Don't stack co-dependent items in the queue.** If B depends on A being merged, either finish A first or build B to work against both code paths.

## Code structure

**Self-contained units.** Each ported item should be one file the user can review in isolation. No central enum, no central match, no shared registry every port has to edit. Conflicts serialise the pipeline.

The anti-pattern is a central enum like:

```rust
pub enum Command {
    TerrainShapeModifyCommand(TerrainShapeModifyCommand),
    TerrainLevelCommand(TerrainLevelCommand),
    // every command — every port edits this list
}
```

The pattern instead is trait + auto-registration. Each command lives in its own file:

```rust
// commands/add_variable_command.rs
pub struct AddVariableCommand { ... }

impl ParseableCommand for AddVariableCommand {
    const CLASS_NAME: &'static str = "AddVariableCommand";
    fn execute(&mut self, ctx: &mut Ctx) { ... }
}

inventory::submit!(CommandRegistration::for_::<AddVariableCommand>());
```

The registry is built at startup from `inventory::iter`. Adding a command = one new file + one `pub mod` line in `mod.rs`. The `mod.rs` line is the only shared edit, and it's append-only with no ordering, so conflicts are trivial.

If `inventory` becomes problematic (e.g. platforms where life-before-`main` link sections misbehave), the fallback is a `build.rs` that scans `commands/*.rs` and generates the registry. Same property: command files stay self-contained.

**Where ported code lives in the tree:**

- Per-command file under [native/src/sbc/commands/](../../native/src/sbc/commands/)`<slice>/` — owns its serde struct, its `inventory::submit!` registration, and its execute/unexecute logic.
- Per-manager file: a per-slice `model`/manager module.
- The command-system internals + the single public `commands_api` surface live under [native/src/sbc/commands/command_system/](../../native/src/sbc/commands/command_system/).
- Cross-slice managers (texture undo stack, heightmap) live where the first slice that needs them puts them; later slices reuse.
- Each slice is a directory; `mod.rs` files only wire submodules, never hold code.

| Layer | Self-contained unit | Registration |
|-------|--------------------|--------------|
| Commands | one file per command | `inventory` keyed by class name |
| State | one file per state | `inventory` keyed by state name |
| Model managers | one file per manager | direct construction in model root (~13 managers, low churn) |
| View handlers (Phase 5) | one file per RmlUi document | `inventory` keyed by document id |

### Slice-owned additions

Feature slices should add files under the slice they belong to instead of
growing shared "everything" files. Shared files are allowed only for stable
infrastructure seams that do not need per-feature edits after the seam lands.

Preferred pattern:

- Rust implementation: `native/src/sbc/<feature>/<thing>.rs`
- Rust in-engine tests: `native/src/sbc/<feature>/tests/`, each test registered
  with `crate::integration_test!("name", func)` (tagged by module path).
- Pytest smoke: the single `tools/smoke/test_integration.py` runs every
  registered test in one boot — no per-slice file, no name list. Filter a slice
  with `SBC_TEST_TAGS=<substring>` (e.g. `textures`, `heightmap`).

Avoid:

- Adding every slice's integration tests to `native/src/sbc/tests/mod.rs`.
  That module is the harness owner; it should not become a feature list.
- Enumerating in-engine test names — or their output artifacts — in Python. The
  Rust `integration_test!` registry is the single source of truth; Python only
  asserts over whatever results come back.
- Adding later-slice managers, commands, or tests to a stable slice just because
  wip has them in a shared file.

When a slice needs one line in a parent `mod.rs`, keep it local to that slice
directory (`commands/heightmap/mod.rs`, `commands/teams/mod.rs`, etc.). The root
module should only change when introducing a new slice directory or a genuinely
new shared subsystem.

**Other anti-patterns to avoid:**

- Central error enum with a variant per command. Use one `CommandError` with a string or `Box<dyn Error>`, or per-command structured errors.
- Central `mod.rs` re-exports listing every command's public types. Keep visibility scoped — commands shouldn't need to expose types outside their own module.
- Shared test fixtures with hard-coded variant lists. Each command's tests live in its own file.

## Build invariant

`cargo check` in `native/` must pass at every commit (in **stable**). The Lua app must still run at every commit. Both halves of the parallel impl exist; only flip one at a time. If a port needs an unfinished dependency, gate behind `cfg`, don't break the build.

The wip dir has no commit invariant — it builds when it builds. If wip is temporarily broken because a refactor is mid-flight, that's fine; the stable side is unaffected.

## Quality bar — pre-handoff

Target: user review + manual test under 2 minutes per item. To get there, every item passes these *before* entering the queue. No "I'll add tests later."

- `cargo fmt --check` clean
- `cargo clippy --all-targets -- -D warnings` zero output (warnings fixed or `#[allow]`-ed with a one-line reason)
- `cargo test` green, including new tests for new logic
- Integration tests green (`uv run pytest` in `tools/smoke/`)
- Self-review: re-read the diff as if reviewing it; cut dead code, fix bad names
- No `unwrap()`/`panic!()` outside tests; use `?` or `expect("specific reason")`
- No leftover `TODO`s
- Cross-platform check (`cargo check --target x86_64-pc-windows-gnu`) if touching FS, threading, or platform APIs

If any check fails, fix it. **Don't pad the queue.** Three clean items beat ten noisy ones — bounce-backs cost the user more than the original review.

## Code style

- **One concept per file.**
- **Imports grouped**: std → external crates → crate-local, separated by blank lines.
- **Errors carry context.** Never bare `?` that drops meaning.
- **Tests live next to code**: `#[cfg(test)] mod tests` at the bottom of the file.
- **Public surface minimal.** `pub(crate)` over `pub` when in doubt.
- **Short functions.** If you scroll to read it, split it.

### Stepdown ordering

Write each file **top-down in call order**: the public entry point first, then
the things it calls, then their callees, with private leaf helpers last. A reader
scrolling top-to-bottom meets each function *before* the helpers it depends on —
the file reads like a newspaper (headline first, detail below).

- In a command file: the `impl Command` block (`execute` / `unexecute` — what the
  framework calls) goes first, then its `stamp`/private methods, then leaf helpers
  (`brush`, `generate_*`), then free functions, then the `register_command!` line.
- Keep one `impl` block per type — don't split a type's methods across several
  `impl` blocks to satisfy ordering; order the methods *within* the block instead.
- Free helper functions go below the code that calls them; a leaf used by several
  callers goes after the last of them.

### Comments

Comment the **why**, not the **what**. The code already says what it does; a
comment earns its place only by explaining something the code can't: a non-obvious
reason, a constraint, a surprising interaction, a deliberate deviation.

- **No WHAT-comments.** `// loop over the points` above a `for` loop is noise.
- **Write WHY-comments** for: why this approach over the obvious one, why an engine
  call is wrapped a certain way, why a value is what it is, what invariant must
  hold. (Example: the `set_height_map_func` wrapper comment explaining the recalc.)
- **Doc-comments (`///`, `//!`)** state a contract — what a caller must know to use
  the item correctly — not a restatement of the body.
- **Keep them true.** A stale comment is worse than none; update or delete it when
  the code moves. Design narrative belongs in `docs/design/`, not in long module
  headers that drift.

## Tests

- **Unit tests** (every item with non-trivial logic): co-located, cover happy path + error paths + edge cases (empty, boundary, large). Skip trivial getters.
- **Integration tests** (`tools/smoke/`, pytest): boot SBC against the dev engine once, then run multiple test files asserting on the resulting infolog. New ports add new test files; common assertions (no errors, no warnings, no crashes) are shared fixtures. Mandatory before any slice is handed off to review.
- **CI** (Phase 0): fmt + clippy + test + cross-Windows check + integration tests on every push.
- **Per-command tests** (each Phase 1 port): a test file that boots SBC (sharing the session boot when possible), drives the command, and asserts on resulting state via infolog or other observable side effect.
- **E2E UI tests** (Phase 4/5): visual regression + a thin RmlUi test driver. Not built yet — RmlUi document IDs should be deterministic so this is buildable later.
- **Benchmarks**: at the very end, once everything is ported. If a user-visible regression appears mid-port, benchmark that one thing; otherwise hold.

### Verifying the bridge end-to-end

The smoke suite boots SBC headless with no input. It proves the native plugin
**compiles, loads, and inits with zero errors/warnings** — it does *not* prove
that a command ever reaches Rust, because nothing fires a command during a
passive boot. `handle_message`'s receive log is at `debug`, and the root logger
is `info`, so a command round-trip is invisible by default. A bridge that
silently dropped every message would still pass all the baseline + plugin tests.

To confirm a command actually crosses the bridge into the native plugin:

1. In [native/log4rs.yaml](../../native/log4rs.yaml), set the `rust_plugin::sbc`
   logger to `level: debug` (the existing commented-out `command_runner` logger
   names a module that doesn't exist — `rust_plugin::sbc` is the right target).
2. Rebuild: `cd native && cargo build --release`.
3. Boot SBC and exercise *any* command (e.g. one terrain brush stroke):
   `cd tools/smoke && uv run python -m run_sbc` prints the write dir, or launch
   the editor manually.
4. Grep the infolog in that write dir for `HandleLuaCall(` — one line per
   command sent. Its payload is the `{tag,data}` JSON the Lua bridge
   ([scen_edit/command/command_manager.lua](../../scen_edit/command/command_manager.lua)
   line ~132) serialized.
5. During the parallel period, commands with no Rust handler log
   `Unknown command class: …` at error level — expected for anything not yet
   ported. Once a class is flipped to Rust-only, that line must disappear.

**This recipe is the precondition for slice 1's per-command tests.** Those tests
("fire the command, assert observable state changed") need a way to drive a
known command into the headless boot — a small autoexec Lua fixture or a synced
call — which does not exist yet. Build that driver before/with slice 1.

### Rules — what tests assert

- **Zero errors and zero warnings, always. No allowlists.** Tests assert exactly this and never weaken it. If something fires, the fix is to fix it at the source — SBC code, dev engine config, missing assets in the test environment — never to exclude the line.
- **Never `git stash` to determine whether a bug pre-exists.** Whether a bug came from this slice or earlier is irrelevant — the test fails, the bug gets fixed.
- **Never bring pre-existing issues up for discussion** — not in commit messages, review-queue rows, or status updates. Surface them by letting the test fail; that's enough signal. Don't write "but this was already there" anywhere.

## Review-queue row format

Every row needs:

- Link to Rust file(s)
- Link to Lua file(s) being replaced
- One-line description
- Test recipe (3–5 numbered steps to run in-game)
- Risk callout if anything unusual (`unsafe`, allocations, global state)
- CI status

If anything's missing, the item isn't ready.

## When in doubt

Ask. Cheaper than redoing work.
