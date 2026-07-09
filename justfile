set shell := ["bash", "-cu"]
set dotenv-load

# Engine paths come from .env (see .env.example) — never hardcode personal paths.
engine_build_dir := env_var_or_default("SBC_ENGINE_BUILD_DIR", "")
engine_rust_dir := env_var_or_default("SBC_ENGINE_RUST_DIR", "")

# Show available recipes.
[private]
default:
    just --list

# Check Rust formatting for the native crate.
[group('lint')]
fmt:
    cd native && cargo fmt --check

# Run clippy on all native targets with warnings denied.
[group('lint')]
clippy:
    cd native && cargo clippy --all-targets --release -- -D warnings

# Run Lua lint.
[group('lint')]
lint-lua:
    luacheck .

# Check simple Rust file ordering conventions.
[group('lint')]
lint-rust-step-down:
    python3 tools/lint/rust_step_down.py

# Check Python step-down ordering (public functions before private `_` helpers).
[group('lint')]
lint-py-step-down:
    python3 tools/lint/py_step_down.py

# Fail on commands defined but never instantiated (dead port leftovers).
[group('lint')]
lint-no-dead-commands:
    python3 tools/lint/no_dead_commands.py --fail

# Run all lints + native type-check (the one command to run before review).
[group('lint')]
lint: fmt clippy lint-lua lint-rust-step-down lint-py-step-down lint-no-dead-commands check

# Type-check the native crate.
[group('build')]
check:
    cd native && cargo check

# Build the native plugin in release mode.
[group('build')]
build-native:
    cd native && cargo build --release

# Build the native plugin in release mode.
[group('build')]
build: build-native

# Build the local engine.
[group('build')]
build-engine:
    cmake --build "{{engine_build_dir}}"

# Build the engine-side spring-native crate after binding changes.
[group('build')]
build-engine-bindings:
    cd "{{engine_rust_dir}}" && cargo build -p spring-native

# Run native Rust unit tests in release mode.
[group('test')]
test-unit:
    cd native && cargo test --release

# Run the integration suite (boots the dev engine), optionally filtered by tag substring.
[group('test')]
test-integration tags="":
    if [ -n "{{tags}}" ]; then cd tools/smoke && SBC_TEST_TAGS="{{tags}}" uv run pytest; else cd tools/smoke && uv run pytest; fi

# Complete run: unit tests, native rebuild, and ALL integration tests incl. slow opt-in ones.
[group('test')]
test-all: test-unit build-native
    cd tools/smoke && SBC_TEST_DEEP="1" SBC_TEST_TIMEOUT="300" uv run pytest

# Run the native verification chain (lint already covers check).
[group('test')]
verify-native: lint test-unit build-native

# Build and run a long-lived isolated Spring editor session.
[group('run')]
run config="config/luaui-chili.json": build-native
    bash tools/dev/launch.sh --config "{{config}}"

# Drive the native chonsole in the currently running editor window.
# Defaults to enter-only; typing scenarios must be requested explicitly.
[group('run')]
smoke-chonsole scenario="enter":
    python3 tools/dev/chonsole_smoke.py "{{scenario}}"

# Run black-box UI E2E tests. Does not rebuild native code; run `just build`
# first when testing Rust UI changes.
[group('test')]
test-e2e target="chonsole" args="":
    python3 tools/e2e/ui_driver.py "{{target}}" {{args}}
