---
name: Porting conventions
description: How the Lua → Rust port is carried out — process, structure, quality
---

# Conventions

## Process

**Parallel implementations.** Lua stays the active path until the Rust replacement is reviewed and manually tested. Both impls live side-by-side; the dispatch layer chooses which runs. Don't delete Lua before Rust is verified.

**File-by-file.** One Lua file → one Rust module. Names align: `add_variable_command.lua` → `add_variable_command.rs`.

**Two human gates** after Claude says "implemented":

1. **Review** — user reads the Rust code.
2. **Manual test** — user runs SBC, exercises the feature.

Claude does lint (`cargo fmt`, `cargo clippy -D warnings`), unit tests, and the smoke harness. Claude never marks anything done.

**Commits.** Only the user authorizes commits — Claude runs `git commit -m` only when told. Small commits: one port (or a small batch of related ports) per commit. The dispatch flip can ride along or come in a follow-up.

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

| Layer | Self-contained unit | Registration |
|-------|--------------------|--------------|
| Commands | one file per command | `inventory` keyed by class name |
| State | one file per state | `inventory` keyed by state name |
| Model managers | one file per manager | direct construction in model root (~13 managers, low churn) |
| View handlers (Phase 5) | one file per RmlUi document | `inventory` keyed by document id |

**Other anti-patterns to avoid:**

- Central error enum with a variant per command. Use one `CommandError` with a string or `Box<dyn Error>`, or per-command structured errors.
- Central `mod.rs` re-exports listing every command's public types. Keep visibility scoped — commands shouldn't need to expose types outside their own module.
- Shared test fixtures with hard-coded variant lists. Each command's tests live in its own file.

## Build invariant

`cargo check` in `native/` must pass at every commit. The Lua app must still run at every commit. Both halves of the parallel impl exist; only flip one at a time. If a port needs an unfinished dependency, gate behind `cfg`, don't break the build.

## Quality bar — pre-handoff

Target: user review + manual test under 2 minutes per item. To get there, every item passes these *before* entering the queue. No "I'll add tests later."

- `cargo fmt --check` clean
- `cargo clippy --all-targets -- -D warnings` zero output (warnings fixed or `#[allow]`-ed with a one-line reason)
- `cargo test` green, including new tests for new logic
- Smoke harness green (once it exists — see Tests below)
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
- **No WHAT-comments.** Only WHY-comments survive review.
- **Public surface minimal.** `pub(crate)` over `pub` when in doubt.
- **Short functions.** If you scroll to read it, split it.

## Tests

- **Unit tests** (every item with non-trivial logic): co-located, cover happy path + error paths + edge cases (empty, boundary, large). Skip trivial getters.
- **Smoke harness** (Phase 0): a scripted Spring run that boots SBC under Xvfb and fails on crash signatures or missing LuaUI init. Mandatory before any command ships.
- **CI** (Phase 0): fmt + clippy + test + cross-Windows check + smoke on every push.
- **Per-command smoke** (each Phase 1 port): scripted command + grep on infolog. Added as each command lands.
- **E2E UI tests** (Phase 4/5): visual regression + a thin RmlUi test driver. Not built yet — RmlUi document IDs should be deterministic so this is buildable later.
- **Benchmarks**: at the very end, once everything is ported. If a user-visible regression appears mid-port, benchmark that one thing; otherwise hold.

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
