# Native Interface ABI Strategy (Revised)

This document describes how the C++ engine and native modules negotiate compatibility, expose new features safely, and validate behavior as the Lua bridge is ported.

## Semantic Versioning

The native interface uses semantic versioning applied to the entire API surface:

- **MAJOR** – incremented when we intentionally break compatibility (removing fields, changing semantics). Modules built against a different major version are rejected.
- **MINOR** – incremented when we add functionality in a backward-compatible way (new functions, new struct fields appended). Older modules continue to run but cannot see the new entries.
- **PATCH** – bug fixes or comment-only changes. No behavior change.

Shared header constants:

```c
#define SPRING_NATIVE_ABI_MAJOR 1
#define SPRING_NATIVE_ABI_MINOR 0
#define SPRING_NATIVE_ABI_PATCH 0
```

Rust bindings (via `build.rs` or generated code) read the same numbers so both sides agree.

## Initialization Handshake

Compatibility is enforced in a single initialization call. The engine exports:

```c
struct NativeInterface;

struct NativeInitParams {
    uint16_t abi_major;
    uint16_t abi_minor;
    uint16_t abi_patch;
    uint32_t engine_commits_number; // optional, parsed from SpringVersion::GetCommits()
};

typedef bool (*NativeModuleInitFn)(const NativeInterface* iface,
                                   const NativeInitParams* params,
                                   struct NativeModuleInfo* out_info);
```

Example engine loader:

```c
bool EngineLoadModule(NativeModuleInitFn initFn) {
    NativeInitParams params;
    params.abi_major = SPRING_NATIVE_ABI_MAJOR;
    params.abi_minor = SPRING_NATIVE_ABI_MINOR;
    params.abi_patch = SPRING_NATIVE_ABI_PATCH;
    params.engine_commits_number = std::atoi(SpringVersion::GetCommits().c_str());

    NativeModuleInfo info = {};
    if (!initFn(&nativeInterface, &params, &info)) {
        return false; // module rejected the engine
    }

    if (info.abi_major != SPRING_NATIVE_ABI_MAJOR)
        return false;

    if (info.abi_minor > SPRING_NATIVE_ABI_MINOR)
        return false;

    RegisterModule(info);
    return true;
}
```
- Requires `<cstdlib>` for `std::atoi`.

The module reports its details through `NativeModuleInfo`:

```c
struct NativeModuleInfo {
    const char* module_name;      // optional diagnostics
    uint16_t abi_major;
    uint16_t abi_minor;
    uint16_t abi_patch;
};
```

Once the handshake succeeds both sides know the shared MAJOR/MINOR numbers and can make decisions about optional features.

## Function Tables

Each domain (SyncedCtrl, MetalMap, etc.) exposes a struct of function pointers inside `NativeInterface`.

Rules:

1. New functions are appended to the end of the struct when MINOR increases.
2. Existing functions keep their signature and semantics until MAJOR changes.
3. The engine always zero-initialises the function table; missing functions appear as `nullptr`.
4. Modules must null-check optional entries if they require features added after their own `abi_minor`.

Example skeleton:

```c
struct NativeSyncedCtrl {
    AddHeightMapFn add_height_map;        // since 1.0
    SetHeightMapFn set_height_map;        // since 1.0
    SetHeightMapFuncFn set_height_map_fn; // since 1.0

    LevelHeightMapFn level_height_map;    // added in 1.1 (nullptr on 1.0)
    AdjustHeightMapFn adjust_height_map;  // added in 1.1
};
```

Usage:

```c
if (moduleInfo.abi_minor >= 1 && iface->synced_ctrl.level_height_map != nullptr) {
    iface->synced_ctrl.level_height_map(&request);
}
```

Because the engine knows the module’s `abi_minor`, it can also avoid calling back into functions the module never provided.

## Struct Layouts and Arrays

Data exchanged across the boundary stays POD:

- Fixed-width integers (`uint32_t`, `int32_t`, etc.) and `float`/`double`.
- Pointers combined with explicit lengths for arrays:
  ```c
  struct FloatArrayView {
      const float* values;
      uint32_t     length;
  };
  ```
- Null-terminated UTF-8 strings where needed (`const char*`).

When a struct grows, new fields are appended. The engine only writes fields that exist for the module’s negotiated MINOR version. Array shapes and helper structs live in the specification directory (`spec/README.md`).

## Call-In / Call-Out Catalogue

- **Call-ins (module → engine)**: the function tables described above. Modules call what they need, guarding `nullptr` for optional entries.
- **Call-outs (engine → module)**: planned via callback tables returned in `NativeModuleInfo` when needed. They will follow the same semver rules (append-only while MINOR increases).

## Hot Reload Workflow

1. Engine unloads the previous shared library and loads the new one.
2. `NativeModuleInitFn` runs again; if the module rejects the current ABI, reload aborts.
3. The module updates its cached pointers to the `NativeInterface` tables.


## Open Items

- Decide on the machine-readable format (YAML/TOML/JSON) that will drive code generation.
- Specify the callback table format once engine-driven call-outs are required.
