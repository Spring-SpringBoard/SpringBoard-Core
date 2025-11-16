# SyncedCtrl API

## Legacy Lua Behaviour
`LuaSyncedCtrl.cpp` defines the authoritative synced-side control surface used by Spring widgets and gadgets. Functions are grouped into team/alliance management, game rules, unit creation and manipulation, projectile control, command queue editing, and terrain sculpting. Many calls accept loose Lua tables or strings to select sub-modes.

## Native Interface Layout
The native ABI replaces the monolithic Lua table with a strongly-typed function table. The engine fills the structure once during initialization and exposes it via `NativeInterface::synced_ctrl`.

```c
#ifdef __cplusplus
extern "C" {
#endif

typedef uint16_t  NativeTeamId;
typedef uint16_t  NativeAllyTeamId;
typedef uint16_t  NativePlayerId;
typedef uint32_t  NativeUnitId;
typedef uint32_t  NativeFeatureId;
typedef uint32_t  NativeProjectileId;
typedef uint16_t  NativeWeaponIndex;  // 0-based

typedef struct { float x, y, z; } NativeVec3;
typedef struct { float x, z; } NativeVec2;

typedef struct {
    float x_min; // world-space (elmos)
    float z_min;
    float x_max;
    float z_max;
} NativeStartBox;

typedef enum {
    NATIVE_RESOURCE_METAL = 0,
    NATIVE_RESOURCE_ENERGY = 1,
} NativeResourceKind;

typedef struct {
    bool has_metal;
    float metal;
    bool has_energy;
    float energy;
} NativeResourcePair;

typedef enum {
    NATIVE_RULES_VALUE_NUMBER,
    NATIVE_RULES_VALUE_BOOLEAN,
    NATIVE_RULES_VALUE_STRING,
} NativeRulesValueType;

typedef struct {
    const char* name;           // UTF-8 key
    NativeRulesValueType type;
    union {
        float number;
        bool boolean;
        const char* string;
    } value;
    uint32_t los_mask;          // bitfield of LuaRulesParams::RULESPARAMLOS_*
} NativeRulesParam;

typedef struct {
    uint32_t unit_def_id;       // mandatory
    NativeTeamId team_id;       // owning team
    NativeVec3 position;        // world space
    uint8_t facing;             // 0..3 (same semantics as LuaUtils::ParseFacing)
    bool being_built;
    bool flatten_ground;
    NativeUnitId requested_unit_id; // optional (0 -> auto)
    NativeUnitId builder_unit_id;   // optional (0 -> none)
} NativeUnitSpawnRequest;

typedef struct {
    bool set_build_time; float build_time;
    bool set_metal_cost; float metal_cost;
    bool set_energy_cost; float energy_cost;
} NativeUnitCostPatch;

typedef struct {
    bool set_health;   float health;
    bool set_capture;  float capture_progress;
    bool set_paralyze; float paralyze_damage;
    bool set_build;    float build_progress;
} NativeUnitHealthPatch;

typedef struct {
    bool set_metal_extraction; float metal_extraction;
    bool set_harvest_storage;  float harvest_storage;
} NativeUnitMetalPatch;

typedef struct {
    bool set_force_use_weapons; bool force_use_weapons;
    bool set_allow_use_weapons; bool allow_use_weapons;
} NativeUnitWeaponUsage;

typedef struct {
    bool set_reload_state;    int32_t reload_frame;
    bool set_reload_time;     float reload_seconds;
    bool set_reaim_time;      int32_t frames;
    bool set_accuracy;        float accuracy;
    bool set_spray_angle;     float spray_angle;
    bool set_range;           float range;
    bool set_projectile_speed;float projectile_speed;
    bool set_auto_target_range_boost; float auto_target_range_boost;
    bool set_burst;           int32_t burst;
    bool set_burst_rate;      float burst_rate_seconds;
    bool set_windup;          float windup_seconds;
    bool set_projectiles;     int32_t projectiles_per_shot;
    bool set_salvo_left;      int32_t salvo_left;
    bool set_next_salvo;      int32_t next_salvo_frame;
    bool set_aim_ready;       bool aim_ready;
    bool set_force_aim;       int32_t decrement_frames; // applied immediately
    bool set_avoid_flags;     int32_t avoid_flags;
    bool set_collision_flags; int32_t collision_flags;
    bool set_ttl;             float ttl_seconds;
} NativeWeaponStatePatch;

typedef struct {
    bool set_paralyze_damage_time; int32_t paralyze_frames;
    bool set_impulse_factor;       float impulse_factor;
    bool set_impulse_boost;        float impulse_boost;
    bool set_crater_mult;          float crater_mult;
    bool set_crater_boost;         float crater_boost;
    bool set_dyn_damage_exp;       float dyn_damage_exp;
    bool set_dyn_damage_min;       float dyn_damage_min;
    bool set_dyn_damage_range;     float dyn_damage_range;
    bool set_dyn_damage_inverted;  bool dyn_damage_inverted;
    bool set_crater_aoe;           float crater_area_of_effect;
    bool set_damage_aoe;           float damage_area_of_effect;
    bool set_edge_effectiveness;   float edge_effectiveness;
    bool set_explosion_speed;      float explosion_speed;
    const struct { const char* armor_type; float damage; }* per_armor_patch;
    size_t per_armor_patch_len;
} NativeWeaponDamagePatch;

typedef struct {
    bool set_blocking;
    bool blocking;
    bool set_solid_object_collidable;
    bool solid_object_collidable;
    bool set_projectile_collidable;
    bool projectile_collidable;
    bool set_ray_segment_collidable;
    bool ray_segment_collidable;
    bool set_crushable;
    bool crushable;
    bool set_block_enemy_pushing;
    bool block_enemy_pushing;
    bool set_block_height_changes;
    bool block_height_changes;
} NativeUnitBlockingPatch;

typedef struct {
    bool set_los_mask; uint8_t los_mask; uint8_t ally_mask;
} NativeUnitLosMaskPatch;

typedef struct {
    bool set_air_los; bool air_los;
    bool set_always_visible; bool always_visible;
    bool set_los; bool los;
    bool set_radar; bool radar;
    bool set_sonar; bool sonar;
    bool set_seismic; bool seismic;
} NativeUnitSensorPatch;

typedef struct {
    bool set_cloak; bool cloaked;
    bool set_stealth; bool stealth;
    bool set_sonar_stealth; bool sonar_stealth;
    bool set_seismic_signature; float seismic_signature;
} NativeUnitStealthPatch;

typedef struct {
    bool set_position;  NativeVec3 position;
    bool set_facing;    uint8_t facing;
    bool set_velocity;  NativeVec3 velocity;
    bool set_rotation;  NativeVec3 rotation;
    bool set_heading;   NativeVec3 heading;
    bool set_mass;      float mass;
} NativeUnitPhysicsPatch;

typedef struct {
    NativeUnitId unit_id;
    int32_t command_id;
    uint8_t options;    // command options bitset
    const float* params;
    size_t params_len;
    uint32_t tag;       // optional tag (0 -> auto)
} NativeUnitCommand;

typedef struct {
    NativeUnitId unit_id;
    const NativeUnitCommand* commands;
    size_t commands_len;
} NativeCommandArray;

// function tables grouped by domain

struct NativeSyncedCtrlTeams {
    bool (*set_ally)(NativeAllyTeamId first, NativeAllyTeamId second, bool allow);
    bool (*set_ally_team_start_box)(NativeAllyTeamId ally, const NativeStartBox* box);
    bool (*assign_player_to_team)(NativePlayerId player, NativeTeamId team);
    bool (*set_global_los)(NativeAllyTeamId ally, bool enabled);
    bool (*kill_team)(NativeTeamId team);
    size_t (*game_over)(const NativeAllyTeamId* winners, size_t winners_len);
    bool (*set_tidal)(float strength);
    bool (*set_wind)(float min_strength, float max_strength);
};

struct NativeSyncedCtrlTeamRes {
    bool (*add_resource)(NativeTeamId team, NativeResourceKind kind, float amount);
    bool (*use_resource)(NativeTeamId team, const NativeResourcePair* request, bool* had_enough);
    bool (*set_resource)(NativeTeamId team, NativeResourceKind kind, float amount);
    bool (*set_share_level)(NativeTeamId team, NativeResourceKind kind, float level);
    bool (*share_resource)(NativeTeamId from_team, NativeTeamId to_team, NativeResourcePair amount);
};

struct NativeSyncedCtrlRules {
    bool (*set_game_param)(const NativeRulesParam* param);
    bool (*set_team_param)(NativeTeamId team, const NativeRulesParam* param);
    bool (*set_player_param)(NativePlayerId player, const NativeRulesParam* param);
    bool (*set_unit_param)(NativeUnitId unit, const NativeRulesParam* param);
    bool (*set_feature_param)(NativeFeatureId feature, const NativeRulesParam* param);
    bool (*call_cob_script)(NativeUnitId unit, const char* script_name, const float* args, size_t args_len, float* return_value);
    bool (*get_cob_script_id)(const char* name, int32_t* script_id_out);
};

struct NativeSyncedCtrlUnits {
    NativeUnitId (*create_unit)(const NativeUnitSpawnRequest* request);
    bool (*destroy_unit)(NativeUnitId unit, bool self_destruct, bool reclaimed, NativeUnitId attacker, bool recycle_id);
    bool (*transfer_unit)(NativeUnitId unit, NativeTeamId new_team, bool given);
    bool (*set_costs)(NativeUnitId unit, const NativeUnitCostPatch* patch);
    bool (*set_resourcing)(NativeUnitId unit, const NativeResourcePair* uncond_use, const NativeResourcePair* uncond_make, const NativeResourcePair* cond_use, const NativeResourcePair* cond_make, NativeResourceKind single_kind, float single_amount);
    bool (*set_storage)(NativeUnitId unit, NativeResourcePair amounts);
    bool (*set_tooltip)(NativeUnitId unit, const char* tooltip);
    bool (*set_health)(NativeUnitId unit, const NativeUnitHealthPatch* patch);
    bool (*set_max_health)(NativeUnitId unit, float max_health);
    bool (*set_stockpile)(NativeUnitId unit, int32_t count, int32_t build_frame);
    bool (*set_use_weapons)(NativeUnitId unit, const NativeUnitWeaponUsage* usage);
    bool (*set_weapon_state)(NativeUnitId unit, NativeWeaponIndex weapon_index, const NativeWeaponStatePatch* patch);
    bool (*set_weapon_damages)(NativeUnitId unit, NativeWeaponIndex weapon_index, const NativeWeaponDamagePatch* patch);
    bool (*set_weapon_max_range)(NativeUnitId unit, NativeWeaponIndex weapon_index, float range);
    bool (*set_experience)(NativeUnitId unit, float experience);
    bool (*add_experience)(NativeUnitId unit, float delta);
    bool (*set_armored)(NativeUnitId unit, bool armored, float armor_mul);
    bool (*set_metal_params)(NativeUnitId unit, const NativeUnitMetalPatch* patch);
    bool (*set_build_params)(NativeUnitId unit, const char* key, const NativeUnitBuildParams* params);
    bool (*set_build_speed)(NativeUnitId unit, const NativeUnitBuildSpeeds* speeds);
    bool (*set_nano_pieces)(NativeUnitId unit, const int32_t* piece_indices, size_t len);
    bool (*set_blocking)(NativeUnitId unit, const NativeUnitBlockingPatch* patch);
    bool (*set_crashing)(NativeUnitId unit, bool crashing);
    bool (*set_shield_state)(NativeUnitId unit, NativeWeaponIndex weapon_index, bool enabled);
    bool (*set_shield_recharge_delay)(NativeUnitId unit, NativeWeaponIndex weapon_index, int32_t delay_frames);
    bool (*set_flanking_bonus)(NativeUnitId unit, const NativeUnitFlankingBonus* bonus);
    bool (*set_physical_state_bit)(NativeUnitId unit, uint32_t bit, bool value);
    bool (*get_physical_state)(NativeUnitId unit, uint32_t* mask_out);
    bool (*set_neutral)(NativeUnitId unit, bool neutral);
    bool (*set_target)(NativeUnitId unit, NativeUnitId target, NativeFeatureId feature_target, const NativeVec3* ground_pos, bool manual_fire);
    bool (*set_mid_and_aim_pos)(NativeUnitId unit, const NativeVec3* mid, const NativeVec3* aim);
    bool (*set_radius_and_height)(NativeUnitId unit, float radius, float height);
    bool (*set_buildee_radius)(NativeUnitId unit, float radius);
    bool (*set_piece_parent)(NativeUnitId unit, int32_t piece, int32_t parent);
    bool (*set_piece_matrix)(NativeUnitId unit, int32_t piece, const float matrix[16]);
    bool (*set_collision_volume_data)(NativeUnitId unit, const NativeCollisionVolume* volume);
    bool (*set_piece_collision_volume_data)(NativeUnitId unit, int32_t piece, const NativeCollisionVolume* volume);
    bool (*set_piece_visible)(NativeUnitId unit, int32_t piece, bool visible);
    bool (*set_sensor_radius)(NativeUnitId unit, NativeResourceKind kind, float radius);
    bool (*set_pos_error_params)(NativeUnitId unit, float delta_pos, float delta_vel, float delta_fall, bool reset);
    bool (*set_move_goal)(NativeUnitId unit, const NativeUnitMoveGoal* goal);
    bool (*set_land_goal)(NativeUnitId unit, const NativeVec3* pos, float radius);
    bool (*clear_goal)(NativeUnitId unit);
    bool (*set_physics)(NativeUnitId unit, const NativeUnitPhysicsPatch* patch);
    bool (*factory_bugger_off)(NativeUnitId factory, const NativeVec3* pos, float radius);
    bool (*bugger_off)(const NativeVec3* pos, float radius, bool reclaim);
    bool (*add_damage)(NativeUnitId unit, float damage, NativeUnitId attacker, NativeWeaponIndex weapon_index, NativeProjectileId projectile_id, bool paralyzer);
    bool (*add_impulse)(NativeUnitId unit, const NativeVec3* impulse);
    bool (*add_seismic_ping)(NativeUnitId unit, NativeTeamId ally_team, const NativeVec3* pos, float strength);
    bool (*add_resource)(NativeUnitId unit, const NativeResourcePair* amount);
    bool (*use_resource)(NativeUnitId unit, const NativeResourcePair* amount);
    bool (*add_object_decal)(NativeUnitId unit, const NativeObjectDecal* decal);
    bool (*remove_object_decal)(NativeUnitId unit);
    bool (*add_grass)(const NativeVec3* pos, float radius, float amount);
    bool (*remove_grass)(const NativeVec3* pos, float radius);
} NativeSyncedCtrlUnits;

// Projectile, command, terrain, etc. definitions omitted for brevity in this snippet (see sections below).

#ifdef __cplusplus
} // extern "C"
#endif
```

> **Note:** Several helper structs referenced above (`NativeUnitBuildParams`, `NativeUnitBuildSpeeds`, `NativeUnitFlankingBonus`, `NativeCollisionVolume`, `NativeUnitMoveGoal`, `NativeObjectDecal`) are defined in the sections that introduce the functions requiring them.

The remainder of this document explains the mapping for every Lua call, grouped by domain. Each entry references the function pointer name inside the `NativeSyncedCtrl` table and the supporting data types.

## Alliance & Game State (`synced_ctrl.teams`)
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.SetAlly(firstAllyTeamID, secondAllyTeamID, ally)` | `bool (*set_ally)(NativeAllyTeamId, NativeAllyTeamId, bool)` | Sets mutual alliance flags. Returns `false` if either ally team is invalid. | Mirrors `teamHandler.SetAlly`.
| `Spring.SetAllyTeamStartBox(allyTeamID, xMin, zMin, xMax, zMax)` | `bool (*set_ally_team_start_box)(NativeAllyTeamId, const NativeStartBox*)` | Coordinates supplied in elmos. | Engine converts to normalized start rectangle, identical to Lua behaviour.
| `Spring.AssignPlayerToTeam(playerID, teamID)` | `bool (*assign_player_to_team)(NativePlayerId, NativeTeamId)` | Only succeeds for synced players. | Equivalent to `teamHandler.Team(team)->AddPlayer`.
| `Spring.SetGlobalLos(allyTeamID, globallos)` | `bool (*set_global_los)(NativeAllyTeamId, bool)` | Enables/disables global LOS. | Throws in Lua; here we return `false` on invalid ally teams.
| `Spring.KillTeam(teamID)` | `bool (*kill_team)(NativeTeamId)` | Gaia team rejection handled internally. | Invokes `CTeam::Died()`.
| `Spring.GameOver(winningAllyTeamIDs)` | `size_t (*game_over)(const NativeAllyTeamId*, size_t)` | Returns number of accepted winners. | Equivalent to pushing winners into `game->GameEnd`.
| `Spring.SetTidal(strength)` | `bool (*set_tidal)(float)` | Strength in engine units. | Calls `envResHandler.LoadTidal`.
| `Spring.SetWind(minStrength, maxStrength)` | `bool (*set_wind)(float, float)` | Strengths in engine units. | Calls `envResHandler.LoadWind`.

## Team Resources (`synced_ctrl.team_res`)
Define helper types:
```c
typedef struct {
    NativeTeamId team;
    NativeResourceKind kind;
    float amount;
} NativeTeamResourceDelta;
```
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.AddTeamResource(teamID, "metal"|"energy", amount)` | `bool (*add_resource)(NativeTeamId, NativeResourceKind, float)` | Amount clamped to ≥0. | Equivalent to `team->AddMetal/AddEnergy`.
| `Spring.UseTeamResource(teamID, resource, amount)` / table variant | `bool (*use_resource)(NativeTeamId, const NativeResourcePair*, bool*)` | Fill `NativeResourcePair` with requested pulls. `had_enough` receives result. | Tracks `resPull` and performs the resource spend.
| `Spring.SetTeamResource(teamID, "metal"|"energy"|"metalStorage"|"energyStorage", amount)` | `bool (*set_resource)(NativeTeamId, NativeResourceKind, float)` | Storage adjustments handled when kind corresponds to storage. | matches Lua.
| `Spring.SetTeamShareLevel(teamID, "metal"|"energy", level)` | `bool (*set_share_level)(NativeTeamId, NativeResourceKind, float)` | Level ∈ [0,1]. | Wraps `team->SetShareLevel`.
| `Spring.ShareTeamResource(oldTeam, newTeam, {metal=?, energy=?})` | `bool (*share_resource)(NativeTeamId, NativeTeamId, NativeResourcePair)` | Accepts both positive values (transfer) and negative (same as Lua). | Validates team IDs.

## Game & Team Rules (`synced_ctrl.rules`)
Define LOS flag constants for native callers (mirror `LuaRulesParams::RULESPARAMLOS_*`).
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.SetGameRulesParam(name, value, losAccess?)` | `bool (*set_game_param)(const NativeRulesParam*)` | `value.type` selects number/bool/string; `los_mask` uses bit flags. | Removing a param is expressed by setting `type` to number and `clear` in `los_mask`? (Use dedicated flag `los_mask = UINT32_MAX` to remove – document). |
| `Spring.SetTeamRulesParam(teamID, ...)` | `bool (*set_team_param)(NativeTeamId, const NativeRulesParam*)` | Same semantics. | Team must be controllable.
| `Spring.SetPlayerRulesParam(playerID, ...)` | `bool (*set_player_param)(NativePlayerId, const NativeRulesParam*)` | Only synced players allowed. |  |
| `Spring.SetUnitRulesParam(unitID, ...)` | `bool (*set_unit_param)(NativeUnitId, const NativeRulesParam*)` |  |  |
| `Spring.SetFeatureRulesParam(featureID, ...)` | `bool (*set_feature_param)(NativeFeatureId, const NativeRulesParam*)` |  |  |
| `Spring.CallCOBScript(unitID, scriptName, args)` | `bool (*call_cob_script)(NativeUnitId, const char*, const float*, size_t, float* ret)` | Returns `false` if script not found. | Equivalent to `CallCOBScript` returning float.
| `Spring.GetCOBScriptID(name)` | `bool (*get_cob_script_id)(const char*, int32_t*)` | Writes script ID to output. |  |

## Unit Spawning & Ownership (`synced_ctrl.units`)
Additional helper structs:
```c
typedef struct {
    bool capture; bool reclaimed; bool recycle_id;
} NativeUnitDestroyOptions;

typedef struct {
    bool given; // true=gift, false=capture
} NativeUnitTransferOptions;
```
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.CreateUnit(unitDefName|id, x, y, z, facing?, teamID?, beingBuilt?, flatten?, unitID?, builderID?)` | `NativeUnitId (*create_unit)(const NativeUnitSpawnRequest*)` | Provide null/zero for optional fields. Returns 0 on failure. | Mirrors `unitLoader->LoadUnit` semantics.
| `Spring.DestroyUnit(unitID, selfd?, reclaimed?, attackerID?, cleanupImmediately?)` | `bool (*destroy_unit)(NativeUnitId, bool, bool, NativeUnitId, bool)` | Equivalent to Lua parameters. | Maximum recursion guarded by engine.
| `Spring.TransferUnit(unitID, newTeamID, given?)` | `bool (*transfer_unit)(NativeUnitId, NativeTeamId, bool)` |  |

### Unit Costs & Resource Flow
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.SetUnitCosts(unitID, { buildTime=?, metalCost=?, energyCost=? })` | `bool (*set_costs)(NativeUnitId, const NativeUnitCostPatch*)` | Set `set_*` flags as needed. | Values clamped ≥ 1.
| `Spring.SetUnitResourcing(unitID, key, amount)` / table variant | `bool (*set_resourcing)(NativeUnitId, const NativeResourcePair*, const NativeResourcePair*, const NativeResourcePair*, const NativeResourcePair*, NativeResourceKind, float)` | Provide up to four pairs (uncond/cond + use/make). For single-key path, set `single_kind` and `single_amount` with others null. | Values are halved internally (retain Lua behaviour).
| `Spring.SetUnitStorage(unitID, {metal=?, energy=?})` | `bool (*set_storage)(NativeUnitId, NativeResourcePair)` | Replaces storage pack. |
| `Spring.SetUnitTooltip(unitID, tooltip)` | `bool (*set_tooltip)(NativeUnitId, const char*)` | UTF-8 string. |

### Health & Experience
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.SetUnitHealth(unitID, scalar|table)` | `bool (*set_health)(NativeUnitId, const NativeUnitHealthPatch*)` | When provided with scalar, set `set_health`. For table, set fields individually. `set_paralyze` toggles stunned state automatically. |
| `Spring.SetUnitMaxHealth(unitID, maxHealth)` | `bool (*set_max_health)(NativeUnitId, float)` | Clamped ≥ current health. |
| `Spring.SetUnitStockpile(unitID, count, buildframe?)` | `bool (*set_stockpile)(NativeUnitId, int32_t, int32_t)` | Build frame optional (`-1` => ignore). |
| `Spring.SetUnitUseWeapons(unitID, force?, allow?)` | `bool (*set_use_weapons)(NativeUnitId, const NativeUnitWeaponUsage*)` | Use `set_*` flags for optional parameters. |
| `Spring.SetUnitWeaponState(unitID, weaponNum, table|key,value)` | `bool (*set_weapon_state)(NativeUnitId, NativeWeaponIndex, const NativeWeaponStatePatch*)` | Provide patch with fields described in struct; omit fields via `set_*` flags. |
| `Spring.SetUnitWeaponDamages(unitID, weaponNum, table|key,value)` | `bool (*set_weapon_damages)(NativeUnitId, NativeWeaponIndex, const NativeWeaponDamagePatch*)` | `per_armor_patch` array holds individual damage overrides by armor-type name. |
| `Spring.SetUnitMaxRange(unitID, weaponNum, range)` | `bool (*set_weapon_max_range)(NativeUnitId, NativeWeaponIndex, float)` |  |
| `Spring.SetUnitExperience(unitID, exp)` | `bool (*set_experience)(NativeUnitId, float)` |  |
| `Spring.AddUnitExperience(unitID, exp)` | `bool (*add_experience)(NativeUnitId, float)` |  |
| `Spring.SetUnitArmored(unitID, armored?, armorMul?)` | `bool (*set_armored)(NativeUnitId, bool, float)` | `armorMul` optional (set to existing when NaN). |

### Sensors & Stealth
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.SetUnitLosMask(unitID, allyTeamID, los, radar?)` | `bool (*set_unit_los_mask)(NativeUnitId, NativeAllyTeamId, const NativeUnitLosMaskPatch*)` | Provide mask bits (same semantics as Lua). |
| `Spring.SetUnitLosState(unitID, allyTeamID, bits)` | `bool (*set_unit_los_state)(NativeUnitId, NativeAllyTeamId, uint8_t losBits, uint8_t airLosBits)` |  |
| `Spring.SetUnitCloak`, `SetUnitStealth`, `SetUnitSonarStealth`, `SetUnitSeismicSignature` | `bool (*set_unit_stealth)(NativeUnitId, const NativeUnitStealthPatch*)` | Set flags individually via patch. |
| `Spring.SetUnitAlwaysVisible(unitID, bool)` & `SetUnitUseAirLos(unitID, bool)` | `bool (*set_unit_visibility)(NativeUnitId, bool always_visible, bool use_air_los)` | Combine into single call for native API. |
| `Spring.SetUnitMetalExtraction`, `SetUnitHarvestStorage` | `bool (*set_metal_params)(NativeUnitId, const NativeUnitMetalPatch*)` | Optional fields for extraction/harvest capacity. |

### Builders & Factories
Additional helper structs:
```c
typedef struct {
    bool set_build_distance; float build_distance;
    bool set_range3d;        bool range3d;
} NativeUnitBuildParams;

typedef struct {
    float build_speed;
    bool set_repair_speed;    float repair_speed;
    bool set_reclaim_speed;   float reclaim_speed;
    bool set_resurrect_speed; float resurrect_speed;
    bool set_capture_speed;   float capture_speed;
    bool set_terraform_speed; float terraform_speed;
} NativeUnitBuildSpeeds;
```
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.SetUnitBuildParams(unitID, key, value)` | `bool (*set_build_params)(NativeUnitId, const NativeUnitBuildParams*)` | `key` selects field; for 3D range use boolean. |
| `Spring.SetUnitBuildSpeed(unitID, buildSpeed, repair?, reclaim?, capture?, terraform?)` | `bool (*set_build_speed)(NativeUnitId, const NativeUnitBuildSpeeds*)` | Speed values expressed in elmos/sec (engine expects frames). |
| `Spring.SetUnitNanoPieces(unitID, piecesTable)` | `bool (*set_nano_pieces)(NativeUnitId, const int32_t*, size_t)` | Indices are zero-based in native struct. |
| `Spring.SetUnitBlocking(unitID, ...)` | `bool (*set_blocking)(NativeUnitId, const NativeUnitBlockingPatch*)` | Set individual options with corresponding flags. |
| `Spring.SetUnitCrashing(unitID, crashing)` | `bool (*set_crashing)(NativeUnitId, bool)` |  |
| `Spring.SetUnitShieldState(unitID, weaponNum, enabled)` | `bool (*set_shield_state)(NativeUnitId, NativeWeaponIndex, bool)` |  |
| `Spring.SetUnitShieldRechargeDelay(unitID, weaponNum, frames)` | `bool (*set_shield_recharge_delay)(NativeUnitId, NativeWeaponIndex, int32_t)` |  |
| `Spring.SetUnitFlanking(unitID, flankingData)` | `bool (*set_flanking_bonus)(NativeUnitId, const NativeUnitFlankingBonus*)` | `NativeUnitFlankingBonus` mirrors `CFlankingBonus` fields: mode, dir vector, mobility add, etc. |
| `Spring.SetUnitPhysicalStateBit(unitID, bit, value)` | `bool (*set_physical_state_bit)(NativeUnitId, uint32_t, bool)` | Bits per `CUnit::PhysicalState`. |
| `Spring.GetUnitPhysicalState(unitID)` | `bool (*get_physical_state)(NativeUnitId, uint32_t*)` | Returns mask through out parameter. |
| `Spring.SetUnitNeutral(unitID, neutral)` | `bool (*set_neutral)(NativeUnitId, bool)` |  |

### Targeting & Positioning
Additional helper structs:
```c
typedef struct {
    bool use_ground; NativeVec3 ground_pos;
    bool use_unit;   NativeUnitId unit_id;
    bool use_feature;NativeFeatureId feature_id;
    bool manual_fire;
} NativeUnitTarget;

typedef struct {
    NativeVec3 pos;
    float radius;
    bool raw_move;
    bool is_building_move;
} NativeUnitMoveGoal;

typedef struct {
    float radius;
    float height;
} NativeUnitRadiusHeight;

typedef struct {
    float impulse_x, impulse_y, impulse_z;
} NativeImpulse;
```
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.SetUnitTarget(unitID, targetID|{...})` | `bool (*set_target)(NativeUnitId, const NativeUnitTarget*)` | Accepts exclusive target specification. |
| `Spring.SetUnitMidAndAimPos(unitID, midVec3, aimVec3)` | `bool (*set_mid_and_aim_pos)(NativeUnitId, const NativeVec3*, const NativeVec3*)` |  |
| `Spring.SetUnitRadiusAndHeight(unitID, radius, height)` | `bool (*set_radius_and_height)(NativeUnitId, const NativeUnitRadiusHeight*)` |  |
| `Spring.SetUnitBuildeeRadius(unitID, radius)` | `bool (*set_buildee_radius)(NativeUnitId, float)` |  |
| `Spring.SetUnitPieceParent(unitID, piece, parent)` | `bool (*set_piece_parent)(NativeUnitId, int32_t, int32_t)` |  |
| `Spring.SetUnitPieceMatrix(unitID, piece, matrix)` | `bool (*set_piece_matrix)(NativeUnitId, int32_t, const float[16])` | Column-major matrix identical to Lua order. |
| `Spring.SetUnitCollisionVolumeData(...)` | `bool (*set_collision_volume_data)(NativeUnitId, const NativeCollisionVolume*)` | `NativeCollisionVolume` mirrors `CollisionVolume` fields (type, scales, offsets, test type). |
| `Spring.SetUnitPieceCollisionVolumeData(...)` | `bool (*set_piece_collision_volume_data)(NativeUnitId, int32_t, const NativeCollisionVolume*)` |  |
| `Spring.SetUnitPieceVisible(unitID, piece, visible)` | `bool (*set_piece_visible)(NativeUnitId, int32_t, bool)` |  |
| `Spring.SetUnitSensorRadius(unitID, sensor, radius)` | `bool (*set_sensor_radius)(NativeUnitId, NativeResourceKind, float)` | Sensor kind enumerated (`metal`= sonar, etc.) Document mapping. |
| `Spring.SetUnitPosErrorParams(unitID, posError, buildError, ...)` | `bool (*set_pos_error_params)(NativeUnitId, float pos_error, float build_error, float fall_error, bool reset)` | Mirroring Lua signature. |
| `Spring.SetUnitMoveGoal(unitID, x, y, z, radius?, speed?, raw?)` | `bool (*set_move_goal)(NativeUnitId, const NativeUnitMoveGoal*)` | Options struct includes raw move and build restrictions. |
| `Spring.SetUnitLandGoal(unitID, x, y, z, radius)` | `bool (*set_land_goal)(NativeUnitId, const NativeVec3*, float)` |  |
| `Spring.ClearUnitGoal(unitID)` | `bool (*clear_goal)(NativeUnitId)` |  |
| `Spring.SetUnitPhysics(unitID, table)` | `bool (*set_physics)(NativeUnitId, const NativeUnitPhysicsPatch*)` | Accepts partial updates for position, velocity, heading, mass. |
| `Spring.SetUnitMass(unitID, mass)` | `bool (*set_mass)(NativeUnitId, float)` | Provided via physics patch but retained for compatibility. |
| `Spring.SetUnitPosition/Rotation/Direction/HeadingAndUpDir/Velocity` | Covered by `set_physics` patch. |
| `Spring.SetFactoryBuggerOff(unitID, pos, radius)` | `bool (*factory_bugger_off)(NativeUnitId, const NativeVec3*, float)` |  |
| `Spring.BuggerOff(pos, radius, commandType?)` | `bool (*bugger_off)(const NativeVec3*, float, bool reclaim)` |  |
| `Spring.AddUnitDamage(unitID, amount, attacker?, weapon?, projectile?, paralyzer?)` | `bool (*add_damage)(NativeUnitId, float, NativeUnitId, NativeWeaponIndex, NativeProjectileId, bool)` | Negative `amount` handled same as Lua. |
| `Spring.AddUnitImpulse(unitID, x, y, z)` | `bool (*add_impulse)(NativeUnitId, const NativeVec3*)` |  |
| `Spring.AddUnitSeismicPing(unitID, allyTeam, x, y, z, strength)` | `bool (*add_seismic_ping)(NativeUnitId, NativeAllyTeamId, const NativeVec3*, float)` |  |
| `Spring.AddUnitResource(unitID, metal?, energy?)` | `bool (*add_resource)(NativeUnitId, const NativeResourcePair*)` |  |
| `Spring.UseUnitResource(unitID, metal?, energy?)` | `bool (*use_resource)(NativeUnitId, const NativeResourcePair*)` |  |
| `Spring.AddObjectDecal(unitID, ...)`
| `Spring.RemoveObjectDecal(unitID)` | `bool (*add_object_decal/remove_object_decal)` | `NativeObjectDecal` replicates decal parameters (texture, width, alpha, life). |
| `Spring.AddGrass(x, z, radius, strength)` / `RemoveGrass` | `bool (*add_grass/remove_grass)(const NativeVec3*, float)` |  |

### Attachments, Weapons & Projectiles
Tables omitted show mapping similar to above; due to length see appendix.

## Terrain Manipulation (`synced_ctrl.terrain`)
The height/smooth mesh APIs use the common structs defined earlier (`TerrainRectUpdate`, `TerrainPointUpdate`, `TerrainFuncDispatch`). Function pointers align with the existing names:
- `float (*add_height_map)(const TerrainPointUpdate*)`
- `float (*set_height_map)(const TerrainPointUpdate*)`
- `float (*set_height_map_func)(const TerrainFuncDispatch*)`
- `void (*level_height_map)(const TerrainRectUpdate*)`
- ... (all variants, including original heightmap and smooth mesh helpers)
- `void (*set_map_square_terrain_type)(uint32_t x, uint32_t z, uint32_t type)`
- `bool (*set_terrain_type_data)(const TerrainTypeRequest*)`

The callbacks run on the simulation thread; callers must ensure thread safety.

## Command Queue Operations (`synced_ctrl.commands`)
Function pointers for the six command helpers:
- `bool (*unit_finish_command)(NativeUnitId, int32_t command_id)`
- `bool (*give_order_to_unit)(NativeUnitId, const NativeUnitCommand*)`
- `bool (*give_order_to_unit_map)(NativeUnitId, const NativeUnitCommand*, size_t point_stride)`
- `bool (*give_order_to_unit_array)(const NativeCommandArray*)`
- `bool (*give_order_array_to_unit)(NativeUnitId, const NativeCommandArray*)`
- `bool (*give_order_array_to_unit_map)(const NativeCommandArray*, size_t point_stride)`
- `bool (*give_order_array_to_unit_array)(const NativeCommandArray*, size_t arrays_len)`
These collapse the Lua overloads into strongly typed requests. Map variants expect points encoded in `params` as consecutive triplets; `point_stride` indicates the grouping size.

## Command Descriptor Editing (`synced_ctrl.cmd_desc`)
- `bool (*edit_unit_cmd_desc)(NativeUnitId unit, uint32_t cmd_index, const NativeCmdDescUpdate* update)`
- `uint32_t (*insert_unit_cmd_desc)(NativeUnitId unit, uint32_t cmd_index, const NativeCmdDesc* desc)`
- `bool (*remove_unit_cmd_desc)(NativeUnitId unit, uint32_t cmd_index)`
`NativeCmdDesc` mirrors `CommandDescription` (id, name, action, tooltip, params, etc.). Updates use optional flags similar to other patches.

## Miscellaneous
- `bool (*set_no_pause)(bool allowed)` corresponds to `Spring.SetNoPause`.
- `bool (*set_experience_grade)(size_t grade_count, const float* thresholds)` wraps `Spring.SetExperienceGrade`.
- `bool (*set_radar_error_params)(NativeTeamId team, float radar_error, float mission_error)` mirrors `Spring.SetRadarErrorParams`.
- `bool (*invoke_native_module)(const char* name, const uint8_t* payload, size_t payload_len)` replaces `Spring.InvokeNativeModule` to trigger engine-provided native hooks.

## Weapon Usage & Attachments (synced_ctrl.units continued)
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.UnitWeaponFire(unitID, weaponNum, targetID?)` | `bool (*unit_weapon_fire)(NativeUnitId, NativeWeaponIndex, const NativeUnitTarget*)` | Optional target overrides. | Forces immediate firing if weapon ready. |
| `Spring.UnitWeaponHoldFire(unitID, weaponNum, hold)` | `bool (*unit_weapon_hold_fire)(NativeUnitId, NativeWeaponIndex, bool)` | Mirrors Lua toggles. | |
| `Spring.ForceUnitCollisionUpdate(unitID)` | `bool (*force_unit_collision_update)(NativeUnitId)` | Rebuilds collision state. | |
| `Spring.UnitAttach(unitID, transportID, piece?)` | `bool (*unit_attach)(NativeUnitId unit, NativeUnitId transport, int32_t piece)` | Piece `-1` for default attachment point. | |
| `Spring.UnitDetach(unitID)` | `bool (*unit_detach)(NativeUnitId unit)` | Detaches from current transport. | |
| `Spring.UnitDetachFromAir(unitID)` | `bool (*unit_detach_from_air)(NativeUnitId unit)` | Cancels air load sequence. | |
| `Spring.SetUnitLoadingTransport(unitID, transportID, state)` | `bool (*set_unit_loading_transport)(NativeUnitId unit, NativeUnitId transport, bool loading)` | Tracks load/unload progress. | |

## Projectile Control (`synced_ctrl.projectiles`)
Define helper structs mirroring the Lua tables:
```c
typedef struct {
    NativeProjectileId projectile;
    float gravity;
} NativeProjectileGravity;

typedef struct {
    NativeProjectileId projectile;
    NativeVec3 velocity;
    NativeVec3 spin_vector;
    float spin_speed;
    float spin_angle;
} NativePieceProjectileParams;

typedef struct {
    NativeProjectileId projectile;
    const char* ceg_name;
} NativeProjectileCEG;

typedef struct {
    NativeUnitId owner_unit;
    NativeWeaponIndex weapon_index;
    const float* params;
    size_t params_len;
} NativeSpawnProjectileRequest;

typedef struct {
    NativeVec3 pos;
    NativeVec3 dir;
    int weapon_def_id;
    NativeUnitId owner_unit;
    float damage;
    float area_of_effect;
    float edge_effectiveness;
    float speed;
    bool only_ground;
    bool air_los;
} NativeSpawnExplosionRequest;
```
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.SetProjectileGravity(projectileID, gravity)` | `bool (*set_projectile_gravity)(const NativeProjectileGravity*)` | Adjusts per-projectile gravity multiplier. | |
| `Spring.SetPieceProjectileParams(projectileID, params)` | `bool (*set_piece_projectile_params)(const NativePieceProjectileParams*)` | Fields map to Lua keys (`velocity`, `spinVec`, `spinSpeed`, `spinAngle`). | |
| `Spring.SetProjectileCEG(projectileID, cegName)` | `bool (*set_projectile_ceg)(const NativeProjectileCEG*)` | Updates CEG trail. | |
| `Spring.SpawnProjectile(defName|defID, params)` | `bool (*spawn_projectile)(const NativeSpawnProjectileRequest*, NativeProjectileId* out_id)` | Returns new projectile ID on success. | |
| `Spring.DeleteProjectile(projectileID)` | `bool (*delete_projectile)(NativeProjectileId)` |  | |
| `Spring.SpawnExplosion(params)` | `bool (*spawn_explosion)(const NativeSpawnExplosionRequest*)` | Mirrors Lua table semantics. | |
| `Spring.SpawnCEG(name, pos, dir, radius?, damage?)` | `bool (*spawn_ceg)(const char*, const NativeVec3*, const NativeVec3*, float radius, float damage)` | Optional arguments default to zero. | |
| `Spring.SpawnSFX(piece, type, pos?, dir?, params?)` | `bool (*spawn_sfx)(NativeUnitId unit, int32_t piece, int32_t type, const NativeVec3* pos, const NativeVec3* dir)` | Numeric SFX flags map to the `SFX` enum. | |

## Terrain Extras
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.SetSquareBuildingMask(x1,z1,x2,z2, mask)` | `bool (*set_square_building_mask)(uint32_t x1, uint32_t z1, uint32_t x2, uint32_t z2, uint8_t mask)` | Adjusts building mask for rectangle. | |

## Global Flags & Experience (`synced_ctrl.misc`)
| Lua Call | Native Pointer | Parameters | Notes |
| --- | --- | --- | --- |
| `Spring.SetNoPause(noPause)` | `bool (*set_no_pause)(bool)` | Toggles game pausing. | |
| `Spring.SetExperienceGrade(grades)` | `bool (*set_experience_grade)(const float* thresholds, size_t len)` | Threshold array identical to Lua order. | |
| `Spring.SetRadarErrorParams(teamID, errScale, errBase, missionError?)` | `bool (*set_radar_error_params)(NativeTeamId, float scale, float base, float mission_error)` | Optional mission error defaults to zero. | |

## Command Queue Helpers
The batch helpers refine the earlier command section:
- `bool (*unit_finish_command)(NativeUnitId unit, uint32_t cmd_id)` — mirrors `Spring.UnitFinishCommand`.
- `bool (*give_order_to_unit)(const NativeUnitCommand* cmd)` — `cmd->unit_id` identifies the unit.
- `bool (*give_order_to_unit_map)(NativeUnitId unit, const NativeUnitCommand* command, const NativeVec3* map_points, size_t point_count)` — map-based variant.
- `bool (*give_order_to_unit_array)(const NativeCommandArray* batch)` — multiple commands for one unit.
- `bool (*give_order_array_to_unit)(NativeUnitId unit, const NativeCommandArray* commands)` — queued batch for one unit.
- `bool (*give_order_array_to_unit_map)(NativeUnitId unit, const NativeCommandArray* commands, const NativeVec3* map_points, size_t point_count)` — combines batch + map positions.
- `bool (*give_order_array_to_unit_array)(const NativeCommandArray* batches, size_t batch_count)` — equivalent to Lua's array-to-array helper.

## Native Module Bridge
`Spring.InvokeNativeModule(payload)` transforms into:
```c
bool (*invoke_native_module)(const char* module_name,
                             const uint8_t* request_payload, size_t request_len,
                             uint8_t* response_buffer, size_t* response_len);
```
The engine routes the request to registered native modules. `response_buffer` may be `NULL`; when non-null, `*response_len` must contain the buffer capacity on entry and the bytes written on return.

## Notes for Implementers
1. **Threading:** All functions run on the synced simulation thread. Native modules must not call these from unsynced contexts.
2. **Error Reporting:** Unlike Lua (which often throws), native functions return `false` when validation fails. Engines should optionally provide logging callbacks for debugging.
3. **ABI Stability:** All structs use fixed-width types; boolean flags guard optional fields. Future extensions append new fields or helper functions, preserving structure layout.
4. **Ownership:** Strings, arrays, and pointers reference engine-managed memory unless explicitly documented. Native modules copy data if they require persistence.
