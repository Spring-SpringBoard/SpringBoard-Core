---
name: Review queue
description: Async review pipeline — items Claude has implemented that are waiting for user review / test / commit
---

# Review queue

Items Claude has finished implementing, awaiting human gates. Top of the list = oldest pending.

Each row has: link to the Rust file, the Lua file it replaces, a one-line description, and what to verify when testing. Claude appends; user moves items off as they're reviewed → tested → committed.

| # | Item | Files | State | What to test |
|--:|------|-------|-------|--------------|
| _(empty)_ | | | | |

## States

- **review** — Claude says implemented, lint + tests green; user hasn't read the code yet
- **tested** — user read it and ran it in-game; ready to commit
- **(removed from this file)** — committed; row deleted, phase doc updated to **done**

## Claude's flow

When finishing a port:

1. Update the matching phase doc — set status **review**.
2. Append a row here with a short test recipe.
3. Move on to the next item (do not wait).

## User's flow

1. **Review**: read the linked Rust file. If happy, mark row **tested** after testing it next.
2. **Test**: launch SBC, do the steps in "What to test". If happy, tell Claude to commit.
3. **Commit**: Claude stages the right files, runs `git commit -m`, deletes the row, updates the phase doc to **done**.

If something fails at any gate: leave a note in the row, kick back to Claude (re-mark the phase-doc entry as **in progress**).

## Dependency rule

Don't stack co-dependent items here. If B needs A merged first, Claude either finishes A through **done** before starting B, or builds B so it works against both old and new versions of A.
