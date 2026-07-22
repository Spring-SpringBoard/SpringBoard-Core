---
name: Porting SBC from Lua to Rust
description: Index and working rules for the Rust migration
---

# Porting SBC from Lua to Rust

The target architecture is a native Rust editor using RmlUi for rendering, with
Lua retained only where Spring requires it for bootstrap or metadata. Rust and
Lua may coexist while a domain is transferred, but exactly one implementation
must own a given runtime action.

## Current strategy

`rust-wip` is the broad source workspace. Before transferring more work, bring
its module boundaries in line with the feature-first architecture. Then move
one small, reviewed domain at a time into `rust-stable`.

- [WIP refactor plan](01-wip-refactor-plan.md) — structural cleanup to perform
  before stable transfers.
- [Stable transfer plan](02-stable-transfer-plan.md) — domain order and slice
  exit criteria.
- [Post-migration cleanup](03-post-migration-cleanup.md) — deferred Lua/library
  removal once stable Rust ownership is complete.

## Working documents

- [Conventions](conventions.md) — WIP/stable workflow, code structure, and test
  invariants.
- [Verification ledger](verification.md) — `TODO → DONE → VERIFIED → APPROVED`
  status and evidence for native UI behaviour.
- [Review queue](review-queue.md) — active stable slices awaiting user review.
- [Deferred improvements](todo.md) — worthwhile WIP work that is not part of an
  active stable slice.

## Testing

Native UI scenarios run against the real editor window:

```bash
just test-e2e <target> --tag ui:rust
```

Every changed golden must be visually inspected before it is recorded as
`ai-reviewed`. Only the user marks a verification-ledger item `APPROVED`.

Living subsystem design documentation belongs under [docs/design](../design/),
including the [command system](../design/command-system.md) and
[async IO](../design/async-io.md).
