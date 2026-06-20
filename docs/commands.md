# Commands

Local developer commands live in the repository [justfile](../justfile).
The manual Spring run uses [tools/dev/launch.sh](../tools/dev/launch.sh),
[tools/dev/script.txt](../tools/dev/script.txt), and
[tools/dev/springsettings.cfg](../tools/dev/springsettings.cfg).

## Setup

One-time, before anything that launches the engine (`just run`, `just test-*`):
copy [.env.example](../.env.example) to `.env` and point `SBC_ENGINE_DIR` at your
built engine install dir (the one containing the `spring` binary). `.env` is
gitignored — your paths never get committed.

```sh
cp .env.example .env
$EDITOR .env       # set SBC_ENGINE_DIR (+ engine build/rust dirs if you build the engine)
```

`launch.sh`, `run_sbc.py`, and the engine-build just recipes all read these from
`.env` (or the real environment) — no hardcoded paths.

## Common

```sh
just run                  # build native plugin and start Spring
just build                # build native plugin
just lint                 # all lints
just test-unit            # native Rust unit tests
just test-integration     # full integration suite (boots the engine)
just test-all             # unit tests + integration suite
```

## Run Spring

```sh
just run
```

This builds the native plugin, creates an isolated temporary write directory,
links this checkout as `games/SpringBoard Core.sdd`, copies the saved Spring
settings/start script, sets `SPRING_NATIVE_MODULE`, and starts the local engine.
It prints the write directory and infolog path before Spring starts. The saved
settings include the same packet/bandwidth limits as `dist_cfg/springsettings.json`.

## Build

```sh
just build-native
just build
just build-engine
just build-engine-bindings
```

## Lint

```sh
just lint
just fmt
just clippy
just lint-lua
```

## Test

```sh
just test-unit
just test-integration
just test-integration textures
just test-integration textures,gfx
just test-all
```

`SBC_TEST_TAGS` is passed through by `test-integration` when a tag argument is
given (it narrows the in-engine registered tests; the other suite files always run).
