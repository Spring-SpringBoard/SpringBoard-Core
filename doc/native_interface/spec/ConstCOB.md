# ConstCOB API

## Legacy Lua Behaviour
`LuaConstCOB.cpp` writes two tables:

- `COB` — integer codes for COB script variables and opcodes.
- `SFX` — bit flags for `Spring.UnitScript.Explode` / `EmitSfx` piece effects.

Lua treats these as immutable constants referenced by BOS/COB scripts and LuaUnitScript helpers.

## Native Interface Design
Provide read-only arrays describing COB constants and SFX flags.

```c
#ifdef __cplusplus
extern "C" {
#endif

struct NativeCobConstant {
    const char* name;   // e.g. "ACTIVATION"
    int32_t     value;  // raw COB constant
};

struct NativeSfxFlag {
    const char* name;    // e.g. "SHATTER"
    int32_t     value;   // flag bit
    uint8_t     category;// 0 = Explode flags, 1 = EmitSfx flags
};

struct NativeConstCOB {
    const struct NativeCobConstant* cob_constants;
    size_t cob_constants_len;

    const struct NativeSfxFlag* sfx_flags;
    size_t sfx_flags_len;

    int32_t (*cob_value_from_name)(const struct NativeConstCOB* self, const char* name);
    const char* (*cob_name_from_value)(const struct NativeConstCOB* self, int32_t value);

    int32_t (*sfx_value_from_name)(const struct NativeConstCOB* self, const char* name);
    const char* (*sfx_name_from_value)(const struct NativeConstCOB* self, int32_t value);
};

typedef const struct NativeConstCOB* (*GetConstCOBFn)(void);

#ifdef __cplusplus
} // extern "C"
#endif
```

### Engine Responsibilities
- Populate the arrays from `CobDefines.h` / `PieceProjectile.h` ensuring names match Lua exactly.
- Keep arrays sorted (e.g. lexicographically by name) to support fast helper implementations.
- Expose `GetConstCOBFn` via the constant registry.

### Consumer Guidance
- Treat all data as immutable.
- Use helper callbacks for bidirectional lookups when translating between script strings and numeric IDs.
