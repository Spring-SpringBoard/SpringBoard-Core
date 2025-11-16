# ConstGame API

## Legacy Lua Behaviour
`LuaConstGame.cpp` builds the `Game` table with engine limits, setup parameters, map/mod metadata, and several lookup collections (`springCategories`, `armorTypes`, etc.). Availability of some fields depends on load state (e.g. map information is nil during LuaIntro).

## Native Interface Design
Expose an immutable snapshot structure describing the same information, with explicit guards indicating which sections are valid.

```c
#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    const char* key;
    int32_t     value;
} NativeGameStringInt;

typedef struct {
    const char* name;
    int32_t     id;
} NativeGameBiEntry;

typedef struct {
    const char* name;
    int32_t     value;
} NativeGameNamedValue;

typedef struct NativeGameInfo {
    // Engine limits (always available)
    uint32_t max_teams;
    uint32_t max_players;
    uint32_t max_units;      // 0 until units are initialized
    float    game_speed;
    float    square_size;
    float    metal_map_square_size;
    float    build_square_size;
    float    build_grid_resolution;
    float    footprint_scale;

    // Setup flags
    bool     has_game_setup;
    int32_t  start_pos_type;
    bool     ghosted_buildings;
    const char* demo_play_name; // optional (may be NULL)

    // Map geometry
    bool     has_map_dims;
    uint32_t map_x_blocks;
    uint32_t map_y_blocks;
    float    map_size_x;
    float    map_size_z;

    // Map info
    bool     has_map_info;
    const char* map_name;
    const char* map_description;
    float    map_hardness;
    float    extractor_radius;
    float    tidal_strength;
    float    water_damage;
    float    gravity;

    // Mod info
    bool     has_mod_info;
    const char* game_name;
    const char* game_short_name;
    const char* game_version;
    const char* game_mutator;
    const char* game_desc;
    const char* mod_name;
    const char* mod_short_name;
    const char* mod_version;
    const char* mod_mutator;
    const char* mod_desc;
    bool     construction_decay;
    float    construction_decay_time;
    float    construction_decay_speed;
    float    multi_reclaim;
    int32_t  reclaim_method;
    int32_t  reclaim_unit_method;
    float    reclaim_unit_energy_cost_factor;
    float    reclaim_unit_efficiency;
    float    reclaim_feature_energy_cost_factor;
    bool     reclaim_unit_drain_health;
    bool     reclaim_allow_enemies;
    bool     reclaim_allow_allies;
    float    repair_energy_cost_factor;
    float    resurrect_energy_cost_factor;
    float    capture_energy_cost_factor;
    uint8_t  transport_air;
    uint8_t  transport_ship;
    uint8_t  transport_hover;
    uint8_t  transport_ground;
    uint8_t  fire_at_killed;
    uint8_t  fire_at_crashing;
    uint8_t  require_sonar_under_water;
    bool     paralyze_on_max_health;
    float    paralyze_decline_rate;
    bool     allow_engine_playerlist;

    // Environment state
    bool     has_simulation_state;
    float    wind_min;
    float    wind_max;
    bool     map_damage;

    // Checksums
    bool     has_checksums;
    const char* map_checksum;
    const char* mod_checksum;

    // Lookup tables (views)
    const NativeGameStringInt* spring_categories;
    size_t spring_categories_len;

    const NativeGameBiEntry* armor_types;
    size_t armor_types_len;

    const NativeGameNamedValue* env_damage_types;
    size_t env_damage_types_len;

    const NativeGameNamedValue* collision_flags;
    size_t collision_flags_len;

    const NativeGameNamedValue* speed_mod_classes;
    size_t speed_mod_classes_len;

    const NativeGameNamedValue* script_notify_types;
    size_t script_notify_types_len;

    struct {
        char color;
        char color_and_outline;
        char reset;
    } text_color_codes;
} NativeGameInfo;

typedef const NativeGameInfo* (*GetConstGameFn)(void);

#ifdef __cplusplus
} // extern "C"
#endif
```

### Engine Responsibilities
- Populate the struct on demand (or lazily cache it) using the same data pushes as Lua.
- Maintain string storage for the lifetime of the engine process.
- Keep arrays sorted by name to enable binary-search utilities if needed.
- Expose `GetConstGameFn` through the constant registry and refresh the snapshot when map/mod metadata changes (e.g., after loading a new game).

### Consumer Guidance
- Check the `has_*` flags before reading optional sections.
- Treat pointer arrays as read-only and copy if mutable data is needed.
- Cache the pointer if repeated queries are required; the engine updates it only on major lifecycle events (map load, mod load).
