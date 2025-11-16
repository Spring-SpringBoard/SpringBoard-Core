# ConstGL API

## Legacy Lua Behaviour
`LuaConstGL.cpp` copies the full set of OpenGL enumeration constants into the `GL` table. Lua scripts use the names (`GL.TRIANGLES`, `GL.UNIFORM_BUFFER`, etc.) to configure draw calls without hardcoding numeric values.

## Native Interface Design
Rather than duplicating hundreds of individual getters, publish a generated catalogue that mirrors the Lua table.

```c
#ifdef __cplusplus
extern "C" {
#endif

// High-level grouping to help consumers request only the categories they care about.
typedef enum {
    NativeGLCategory_Primitives,
    NativeGLCategory_Blending,
    NativeGLCategory_Comparison,
    NativeGLCategory_Logic,
    NativeGLCategory_Rasterization,
    NativeGLCategory_BufferTargets,
    NativeGLCategory_PixelFormats,
    NativeGLCategory_ShaderEnums,
    NativeGLCategory_StateFlags,
    NativeGLCategory_TextureParameters,
    NativeGLCategory_FramebufferAttachments,
    NativeGLCategory_QueryTargets,
    NativeGLCategory_Other,
} NativeGLCategory;

typedef struct {
    const char*     name;      // e.g. "TRIANGLES"
    uint32_t        value;     // the GL_ constant
    NativeGLCategory category; // category hint for filtering
} NativeGLConstant;

typedef struct NativeConstGL {
    const NativeGLConstant* constants; // sorted by name
    size_t constants_len;

    // Optional secondary index grouped by category for faster iteration.
    const size_t* category_offsets;    // size NativeGLCategory_Other+1 (offset per category)

    uint32_t (*value_from_name)(const struct NativeConstGL* self, const char* name);   // returns 0 if not found
    const char* (*name_from_value)(const struct NativeConstGL* self, uint32_t value);  // NULL if not found
} NativeConstGL;

typedef const NativeConstGL* (*GetConstGLFn)(void);

#ifdef __cplusplus
} // extern "C"
#endif
```

### Engine Responsibilities
- Auto-generate `NativeGLConstant` entries from the same source lists used in `LuaConstGL.cpp` to avoid drift (a codegen step can parse the `PUSH_GL` macros).
- Keep the array sorted lexicographically; populate `category_offsets` so `category_offsets[c]` points to the first element of that category.
- Implement the helper callbacks using binary search / lookups on the sorted array.
- Expose `GetConstGLFn` via the native constant registry.

### Consumer Guidance
- Use `value_from_name` / `name_from_value` for translation rather than hardcoding GL enums in native modules.
- Iterate ranges by category using `category_offsets` if a module only needs, for example, texture targets or buffer bindings.
- Treat all data as immutable for the lifetime of the process.
