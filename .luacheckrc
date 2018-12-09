
self = false
unused = false
-- unused_args = false
global = true
allow_defined_top = true
max_line_length = false
codes = true

-- Something to think about in the future
-- max_cyclomatic_complexity = 10

-- Lua (unnecessary)
-- "os", "pairs", "math", "pcall", "table", "type", "unpack", "assert",
-- "ipairs", "tostring", "tonumber", "debug", "getfenv", "setfenv",
-- "loadstring", "io", "xpcall", "string", "collectgarbage",
-- "getmetatable", "setmetatable", "next",

-- Default is probably fine, but anyway
std=lua51

globals = {
    -- std extensions
    "math.round", "math.bit_or",
    "table.ifind", "table.show", "table.save", "table.echo",
    -- Spring
    "Spring", "VFS", "gl", "GL", "Game",
    "UnitDefs", "UnitDefNames", "FeatureDefs", "FeatureDefNames",
    "WeaponDefs", "WeaponDefNames", "LOG", "KEYSYMS", "CMD", "Script",
    "SendToUnsynced",
    -- Gadgets
    "GG", "gadgetHandler", "gadget",
    -- Widgets
    "WG", "widgetHandler", "widget",
    -- Libs
    "LCS", "Path", "Table", "Log", "String", "Shaders", "Time", "Array",
    "Platform",
    -- SB speciifc
    "SB", "SB_DIR"
}