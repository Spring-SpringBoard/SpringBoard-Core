# ConstEngine API

## Legacy Lua Behaviour
`LuaConstEngine.cpp` exposes the `Engine` table with build metadata, simulator constants, feature toggles, and font color codes. Lua scripts read this information to adapt to engine capabilities.

## Native Interface Design
Package the same data into a snapshot struct available through the native interface.

```c
#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    bool negative_get_unit_current_command;
    bool has_exit_only_yardmaps;
    int32_t rml_ui_api_version;
    bool no_auto_show_metal;
    int32_t max_pieces_per_model;
    bool transforms_in_gl4;
    float gunship_cruise_altitude_multiplier;
    bool no_refund_for_construction_decay;
    bool no_refund_for_factory_cancel;
    bool no_offset_for_feature_id;
    bool no_handicap_for_reclaim;
    bool group_add_doesnt_select;
} NativeEngineFeatureSupport;

typedef struct {
    char color;            // inline color indicator
    char color_and_outline; // extended indicator
    char reset;            // reset indicator
} NativeEngineTextColorCodes;

typedef struct NativeEngineInfo {
    const char* version;
    const char* version_full;
    const char* version_major;
    const char* version_minor;
    const char* version_patch_set;
    const char* commits_number;
    const char* build_flags;
    uint32_t word_size_bits;    // 0 when called from synced context
    float    game_speed;        // GAME_SPEED

    NativeEngineFeatureSupport feature_support;
    NativeEngineTextColorCodes  text_color_codes;
} NativeEngineInfo;

// Returns a pointer to the immutable engine info snapshot.
typedef const NativeEngineInfo* (*GetConstEngineFn)(void);

#ifdef __cplusplus
} // extern "C"
#endif
```

### Engine Responsibilities
- Populate `NativeEngineInfo` during initialization using the same values pushed to Lua.
- Ensure string pointers remain valid for the lifetime of the process (e.g. static storage or interned buffers).
- Expose `GetConstEngineFn` from the constant registry (e.g. `iface->const_tables.get_engine`).

### Consumer Guidance
- Call `get_engine()` once and cache the pointer if needed; values are constant.
- Copy strings if ownership or mutation is required.
