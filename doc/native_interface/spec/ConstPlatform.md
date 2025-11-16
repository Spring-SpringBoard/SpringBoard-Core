# ConstPlatform API

## Legacy Lua Behaviour
`LuaConstPlatform.cpp` populates the `Platform` table with GPU/driver capabilities, SDL versions, video mode enumerations, and OS/hardware metadata. These values help Lua scripts adapt to user hardware (e.g. enabling GL extensions conditionally).

## Native Interface Design
Provide an immutable snapshot describing the same information, plus array views for enumerations.

```c
#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    const char* display_name;  // e.g. "Display 0"
    int32_t     display_index;
    int32_t     width;
    int32_t     height;
    int32_t     bits_per_pixel;
    int32_t     refresh_hz;
} NativeVideoMode;

typedef struct NativePlatformInfo {
    // GPU & driver
    const char* gpu;
    const char* gpu_vendor;
    uint32_t    gpu_memory_mb;

    const char* gl_version_short;
    uint32_t    gl_version_num;
    const char* glsl_version_short;
    uint32_t    glsl_version_num;

    const char* gl_version;
    const char* gl_vendor;
    const char* gl_renderer;
    const char* glsl_version;
    const char* glad_version;
    const char* glew_version; // compatibility alias

    // SDL versions
    uint32_t sdl_compiled_major;
    uint32_t sdl_compiled_minor;
    uint32_t sdl_compiled_patch;
    uint32_t sdl_linked_major;
    uint32_t sdl_linked_minor;
    uint32_t sdl_linked_patch;

    // Enumerated modes
    const NativeVideoMode* video_modes;
    size_t video_modes_len;

    uint32_t num_displays;

    // GL capability flags
    bool gl_support_non_power_of_two_tex;
    bool gl_support_texture_query_lod;
    bool gl_support_msaa_framebuffer;
    bool gl_have_amd;
    bool gl_have_nvidia;
    bool gl_have_intel;
    bool gl_have_glsl;
    bool gl_have_gl4;
    uint32_t gl_support_depth_buffer_bit_depth;
    bool gl_support_restart_primitive;
    bool gl_support_clip_space_control;
    bool gl_support_frag_depth_layout;
    bool gl_support_seamless_cube_maps;

    // OS / hardware metadata
    const char* os_name;
    const char* os_version;
    const char* os_family;
    const char* hw_config;
    uint32_t cpu_logical_cores;
    uint32_t cpu_physical_cores;
    const char* cpu_brand;
    uint64_t total_ram_mb;

    const char* sys_info_hash;
    const char* mac_addr_hash;
} NativePlatformInfo;

typedef const NativePlatformInfo* (*GetConstPlatformFn)(void);

#ifdef __cplusplus
} // extern "C"
#endif
```

### Engine Responsibilities
- Populate `NativePlatformInfo` during renderer initialization using `GlobalRenderingInfo` and platform helpers.
- Maintain string storage for the lifetime of the process.
- Update the snapshot when the renderer is rebuilt (e.g. after device loss) if values can change.
- Expose `GetConstPlatformFn` through the constant registry.

### Consumer Guidance
- Read the snapshot to configure native module behaviour (e.g. checking for GL4 support).
- Treat the data as immutable; copy strings if needed.
- Iterate `video_modes` when presenting display options to users.
