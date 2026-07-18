---
name: Review queue
description: Async review pipeline — items awaiting user review, test, and authorized stable commit
---

# Review queue

There are currently no queued stable slices.

Each section added below is one implemented stable slice awaiting human gates.
The oldest pending item belongs first.

## Entry format

```md
## <Domain> — <one-line description> — *review*

- Rust: `native/src/sbc/...`
- Lua replaced/disabled: `...` (or `none`)
- Risk: <unsafe, engine binding, allocation, global state, or none>
- CI: `<command>` — <result>

In-game verification:

1. ...
2. ...
3. ...
```

The recipe must be short, observable, and specific to the slice. Include the
relevant focused tests and E2E target, not a blanket request to retest the app.

## States

- **review** — implemented; user has not yet reviewed the code.
- **tested** — user reviewed and tested it in-game; ready for an authorized
  stable commit.
- **removed from this file** — committed to stable; its verification evidence
  remains in `verification.md`.

## Flow

1. Before adding an item, satisfy the slice exit criteria in
   [02-stable-transfer-plan.md](02-stable-transfer-plan.md).
2. Add the entry with exact files, risks, CI result, and in-game recipe.
3. User reviews, tests, and authorizes the stable commit.
4. After the commit, remove the entry and update the verification ledger.

Do not stack co-dependent entries. Finish a prerequisite slice through stable
review before queuing a dependent one, or make the later slice work with both
implementations.
