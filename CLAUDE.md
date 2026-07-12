# Working in this repo

## Use `just` for every dev command

Never invoke `cargo`, `pytest`, `luacheck` or `tools/e2e/ui_driver.py` directly. The
recipes carry the right directories, flags and env (the crate lives in `native/`, so
plain `cargo` from the repo root does not even find a `Cargo.toml`).

| Task | Command |
| --- | --- |
| All lints + type-check (before review) | `just lint` |
| Rust format check | `just fmt` |
| Clippy (warnings denied) | `just clippy` |
| Lua lint | `just lint-lua` |
| Type-check native | `just check` |
| Build native plugin | `just build` (alias of `just build-native`) |
| Build the engine | `just build-engine` |
| Build engine-side bindings | `just build-engine-bindings` |
| Rust unit tests | `just test-unit` |
| Integration suite (boots engine) | `just test-integration` (or `just test-integration <tag>`) |
| Everything, incl. slow tests | `just test-all` |
| Native verification chain | `just verify-native` |
| UI e2e (build native first!) | `just test-e2e <target> "<args>"` |
| Long-lived editor session | `just run config/ui-chili.json` |

E2E examples — `just build` first, `test-e2e` does not rebuild:

    just test-e2e units-panel "--tag ui:rust"
    just test-e2e collision "--tag ui:rust"
    just test-e2e dev-console "--tag ui:chili"

`just --list` shows every recipe.

## Use the file tools, not shell text tools

Read files with **Read**; change them with **Edit**/**Write**. Do not use `sed`, `cat`,
`head`, `tail`, or python one-liners to read or edit a file, and do not use `grep` as a
substitute for opening it. Searching to *locate* a file is fine — once located, Read it.
Partial views are how bugs get misread and invented.

## Never run destructive git

No `git checkout`, `git stash`, `git restore`, `git reset`. The tree carries a lot of
uncommitted work. Undo by hand, with edits.
