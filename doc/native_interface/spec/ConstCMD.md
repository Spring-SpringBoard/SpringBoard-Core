# ConstCMD API

## Legacy Lua Behaviour
`LuaConstCMD.cpp` populates the `CMD` table with:

- Option bit flags (`CMD.OPT_*`).
- State constants (move, fire, wait).
- A bidirectional map between command names and numeric IDs (`CMD.ATTACK == 20`, `CMD[20] == "ATTACK"`).
- Backwards-compatibility aliases (e.g. `CMD.DGUN` → `CMD.MANUALFIRE`).

Lua expects these values to be immutable and available in both synced and unsynced environments.

## Native Interface Design
Expose the same data through a read-only C ABI so native modules can look up command identifiers without going through Lua.

```c
#ifdef __cplusplus
extern "C" {
#endif

struct NativeCmdLabeledValue {
    const char* name;   // UTF-8, null-terminated
    int32_t     value;  // option bit, state code, wait code, etc.
};

struct NativeCmdCommandEntry {
    const char* name;   // e.g. "ATTACK"
    int32_t     id;     // e.g. 20
};

struct NativeCmdAlias {
    const char* alias;  // e.g. "DGUN"
    int32_t     id;     // maps to command id
};

struct NativeConstCMD {
    const struct NativeCmdLabeledValue* option_flags;   // OPT_* entries
    size_t option_flags_len;

    const struct NativeCmdLabeledValue* move_states;    // MOVESTATE_*
    size_t move_states_len;

    const struct NativeCmdLabeledValue* fire_states;    // FIRESTATE_*
    size_t fire_states_len;

    const struct NativeCmdLabeledValue* wait_codes;     // WAITCODE_*
    size_t wait_codes_len;

    const struct NativeCmdCommandEntry* commands;       // CMD.* identifiers
    size_t commands_len;

    const struct NativeCmdAlias* aliases;               // compatibility aliases
    size_t aliases_len;

    // Helper callbacks provided by the engine (fast lookups over generated tables)
    int32_t (*id_from_name)(const struct NativeConstCMD* self, const char* name);
    const char* (*name_from_id)(const struct NativeConstCMD* self, int32_t id);
};

// Returns a pointer to an immutable singleton owned by the engine.
// The pointer remains valid for the lifetime of the process.
typedef const struct NativeConstCMD* (*GetConstCMDFn)(void);

#ifdef __cplusplus
} // extern "C"
#endif
```

### Engine Responsibilities
- Populate the arrays at initialization using the same source data as `LuaConstCMD.cpp` and keep them sorted by name for deterministic lookups.
- Implement `id_from_name` / `name_from_id` as pure, thread-safe helpers (e.g. binary search over the sorted arrays).
- Expose `GetConstCMDFn` from the `NativeInterface` (e.g. `iface->const_tables.get_cmd`).

### Consumer Guidance
- Treat all pointers as read-only; copy strings/values if mutability is required.
- Cache the returned pointer if desired—no hot-reload updates are expected for constants.
- Use the helpers for lookups rather than scanning arrays manually.
