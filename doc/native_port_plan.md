# Native Interface Port Plan

## Overview
This document tracks the multi-phase effort to port the existing Lua-facing engine interfaces to a native interface usable by Rust (and future native modules). It will be updated as phases progress.

## Phases

### Phase 0 – Baseline Audit
- **Status:** In progress. Tracking findings in `doc/native_interface/spec/README.md` (Markdown format for now).
- Catalogue every callout in the Lua bridge (`spring-bar/rts/Lua/*.cpp`), grouped by domain (SyncedCtrl, SyncedRead, UnsyncedCtrl, UnsyncedRead, rendering, etc.).
- Record argument shapes, return semantics, shared helper types, and state requirements into a living spec (planned location: `doc/native_interface/spec/README.md`).
- Identify reusable helper logic that already exists in the engine C++ code and note differences between Lua and native expectations.

### Phase 1 – Interface Definition
- Derive strongly typed signatures from the Lua audits, favouring fixed-width integer and POD struct types.
- Decide where Lua tables should become `{len, ptr}` buffers or arrays of structs for efficiency.
- Capture lifetime/ownership rules, mutability, and error contracts in the shared spec so C++ and Rust rely on the same source of truth.

### Phase 2 – Engine Scaffolding
- Rename `spring-bar/rts/Game/Rust` to a neutral namespace (e.g. `spring-bar/rts/Game/NativeApi`).
- Split the monolithic files into per-domain headers/implementations (mirroring the Lua layout like `LuaSyncedCtrl.cpp`).
- Introduce a registry/aggregator that assembles per-domain function tables instead of maintaining a single giant struct.

### Phase 3 – Engine Implementation
- For each module/domain, expose typed helpers that replace the Lua glue, reusing existing engine utilities where possible.
- When Lua relied on `lua_State`, write conversion helpers that populate typed buffers/structs before invoking shared logic.
- Ensure call-ins used by modules are surfaced through the registry with stable ABI layouts and well-defined error handling.

### Phase 4 – Rust Side
- Mirror the per-module layout under `native/src/interface`, replacing the current all-in-one `native/src/native_interface.rs`.
- Auto-generate `extern "C"` bindings from the shared spec and wrap them in safe Rust traits exposing slices/structs.
- Refactor `native/src/spring.rs` so the global handle dereferences into modular traits rather than a mega-trait.

### Phase 5 – Tooling & Build
- Add a code generation step (build script or `just` recipe) that reads the spec and emits both C++ headers and Rust FFI modules.
- Update engine CMake and the Rust crate (`build.rs`) to run the generator and link the renamed folder.
- Version the consolidated ABI metadata to make compatibility checks easier.

### Phase 6 – Verification
- Create conformance tests for each domain (unit tests or integration harness comparing Lua vs native behaviour).
- Add a smoke Rust plugin that exercises the new calls and validates loader behaviour (`RustSystem::Reload`).
- Extend CI/jobs to build both engine and native crate, running regression automation.

## ABI Strategy
- Detailed compatibility notes are tracked in `doc/native_interface/abi.md` covering versioning, detection, and performance trade-offs.

## Architectural Notes
- Introduce shared POD structs (e.g. `struct UnitList { uint32_t count; const uint32_t* ids; };`) so both sides use identical container representations.
- Store interface slices in a registry keyed by module, enabling consumers to opt into only the domains they need.
- Keep module-level documentation close to the generated headers describing threading rules and parameter expectations.
- Plan a naming sweep once the new layout builds to remove Rust-specific wording and accommodate future native runtimes.

## Next Steps
1. Evaluate long-term machine-readable spec format (YAML vs TOML) while using Markdown for ongoing notes.
2. Extend Phase 0 audit to LuaSyncedCtrl unit/feature controls and LuaUnsyncedCtrl camera hooks.

Last updated: 2025-09-27T21:57:00
