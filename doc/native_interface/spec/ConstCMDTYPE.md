# ConstCMDTYPE API

## Legacy Lua Behaviour
`LuaConstCMDTYPE.cpp` builds the `CMDTYPE` table containing cursor/argument mode identifiers (e.g. `CMDTYPE.ICON`, `CMDTYPE.ICON_AREA`). The table is bidirectional: numeric indices return the string labels.

## Native Interface Design
Map the command types to a compact C data set with lookup helpers.

```c
#ifdef __cplusplus
extern "C" {
#endif

struct NativeCmdTypeEntry {
    const char* name;            // e.g. "ICON_MAP"
    int32_t     code;            // e.g. 10
    const char* return_signature;// optional documentation string, e.g. "mappos"
};

struct NativeConstCMDTYPE {
    const struct NativeCmdTypeEntry* types; // sorted ascending by code
    size_t types_len;

    int32_t (*code_from_name)(const struct NativeConstCMDTYPE* self, const char* name);
    const char* (*name_from_code)(const struct NativeConstCMDTYPE* self, int32_t code);
};

typedef const struct NativeConstCMDTYPE* (*GetConstCMDTYPEFn)(void);

#ifdef __cplusplus
} // extern "C"
#endif
```

### Engine Responsibilities
- Generate the `NativeCmdTypeEntry` array directly from the same definitions used by Lua (`CMDTYPE_*` constants).
- Keep `types` sorted by `code` and ensure names are all upper-case, matching Lua.
- Implement lookup helpers for O(log n) queries.
- Expose `GetConstCMDTYPEFn` alongside the other constant tables.

### Consumer Guidance
- Cache the returned struct pointer if frequent lookups are needed.
- Use the helper callbacks to translate between names and codes; do not mutate the arrays.
