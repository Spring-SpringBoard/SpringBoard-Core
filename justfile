set shell := ["bash", "-cu"]
set dotenv-load

# Engine paths come from .env (see .env.example) — never hardcode personal paths.
engine_build_dir := env_var_or_default("SBC_ENGINE_BUILD_DIR", "")
engine_rust_dir := env_var_or_default("SBC_ENGINE_RUST_DIR", "")
tool_pythonpath := "build:tools"

# Show available recipes.
[private]
default:
    just --list

# Apply mechanical formatting before the checks below.
[group('lint')]
fmt:
    cd native && cargo fmt
    PYTHONPATH="{{tool_pythonpath}}" uv run --locked ruff check --fix build tools
    PYTHONPATH="{{tool_pythonpath}}" uv run --locked ruff format build tools

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
    PYTHONPATH="{{tool_pythonpath}}" uv run --locked sbc-lint rust-step-down

# Check Python step-down ordering (public functions before private `_` helpers).
[group('lint')]
lint-py-step-down:
    PYTHONPATH="{{tool_pythonpath}}" uv run --locked sbc-lint py-step-down

# Fail on commands defined but never instantiated (dead port leftovers).
[group('lint')]
lint-no-dead-commands:
    PYTHONPATH="{{tool_pythonpath}}" uv run --locked sbc-lint no-dead-commands --fail

# Fail when a mod.rs defines functions instead of only wiring submodules.
[group('lint')]
lint-mod-only-declares:
    PYTHONPATH="{{tool_pythonpath}}" uv run --locked sbc-lint mod-only-declares

# Run all lints + native type-check (the one command to run before review).
[group('lint')]
lint: fmt clippy lint-lua lint-rust-step-down lint-py-step-down lint-no-dead-commands lint-mod-only-declares check

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

# Build the Linux editor archive for distributors.
[group('build')]
bundle-base-linux version output="artifacts/SpringBoard-Core-linux-x86_64.sdz": build-native
    PYTHONPATH="{{tool_pythonpath}}" uv run --locked sbc-packager-base \
      --repo-root . \
      --native-plugin ./native/target/release/librust_plugin.so \
      --output "{{output}}" \
      --platform linux \
      --run-config ./config/ui-rust.json \
      --version "{{version}}"

# Build the complete Linux application from an unmodified engine release
# archive. Extraction and pruning are part of this command.
[group('build')]
bundle-application-linux engine_archive version output="artifacts/SpringBoard-linux-x86_64": build-native
    PYTHONPATH="{{tool_pythonpath}}" uv run --locked sbc-packager-application \
      --repo-root . \
      --distribution ./build/distribution.json \
      --output-dir "{{output}}" \
      --native-plugin ./native/target/release/librust_plugin.so \
      --engine-archive "{{engine_archive}}" \
      --platform linux \
      --run-config ./config/ui-rust.json \
      --version "{{version}}"

# Build the local engine, through its Docker toolchain (see the engine's
# AGENTS.md). A host `cmake --build` of the build dir cannot work: that dir is
# configured with the container's paths (`/build/src/...`), so ninja tries to
# mkdir /build and fails. Writes the ready-to-use install to
# <engine>/build-amd64-linux/install, which is what .env points at.
#
# `jobs` is capped rather than left to ninja: unbounded, the container takes the
# whole machine down. Raise it if you have the cores to spare.
[group('build')]
build-engine jobs="8" args="-DUSE_ASAN=ON":
    cd "$(dirname "{{engine_build_dir}}")" && ./docker-build-v2/build.sh -j {{jobs}} linux {{args}}

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
    if [ -n "{{tags}}" ]; then SBC_TEST_TAGS="{{tags}}" PYTHONPATH="{{tool_pythonpath}}" uv run --locked pytest tools/smoke; else PYTHONPATH="{{tool_pythonpath}}" uv run --locked pytest tools/smoke; fi

# Complete run: unit tests, native rebuild, and ALL integration tests incl. slow opt-in ones.
[group('test')]
test-all: test-unit build-native
    SBC_TEST_DEEP="1" SBC_TEST_TIMEOUT="300" PYTHONPATH="{{tool_pythonpath}}" uv run --locked pytest tools/smoke

# Run the native verification chain (lint already covers check).
[group('test')]
verify-native: lint test-unit build-native

# Run the editor with the Dev tab's control gallery: every field control in one
# place, to look at or drive by hand. Off in a normal session.
[group('run')]
dev-panel config="config/ui-rust.json": build-native
    SBC_DEV_PANEL=1 PYTHONPATH="{{tool_pythonpath}}" uv run --locked sbc-smoke manual --config "{{config}}"

# Build and run a long-lived isolated Spring editor session.
[group('run')]
run config="config/ui-rust.json": build-native
    PYTHONPATH="{{tool_pythonpath}}" uv run --locked sbc-smoke manual --config "{{config}}"

# Run black-box UI E2E tests. Does not rebuild native code; run `just build`
# first when testing Rust UI changes.
[group('test')]
test-e2e target *args:
    PYTHONPATH="{{tool_pythonpath}}" uv run --locked sbc-e2e run "{{target}}" {{args}}

# List every reference image and whether it is approved or still ai-reviewed.
[group('test')]
goldens-status:
    @PYTHONPATH="{{tool_pythonpath}}" uv run --locked sbc-e2e goldens-status

# Approve a case's reference images (the human OK): `just goldens-approve rotation-rust`.
# Optionally name individual shots. Only a human runs this.
[group('test')]
goldens-approve case *shots:
    PYTHONPATH="{{tool_pythonpath}}" uv run --locked sbc-e2e approve-goldens "{{case}}" {{shots}}

# Path of the most recent e2e run, optionally for one target: `just e2e-dir rotation`.
[group('test')]
e2e-dir target="":
    @ls -dt artifacts/ui-e2e/*{{target}}* | head -1

# Grep the most recent run's engine log: `just e2e-log rotation "editor state"`.
[group('test')]
e2e-log target pattern:
    @grep -o ".\{0,20\}{{pattern}}.\{0,120\}" "$(ls -dt artifacts/ui-e2e/*{{target}}* | head -1)/infolog.txt" || echo "no match"

# Open the most recent run's screenshots dir: `just e2e-shots rotation`.
[group('test')]
e2e-shots target="":
    @ls "$(ls -dt artifacts/ui-e2e/*{{target}}* | head -1)/screens"
