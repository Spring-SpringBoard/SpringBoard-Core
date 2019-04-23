
self = false
unused = false
-- unused_args = false
global = false --  IDEs tend to have issues with 'global = true', as they work on a per-file basis
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
    "table.ifind", "table.show", "table.save", "table.echo", "table.print",
    -- Spring
    "Spring", "VFS", "gl", "GL", "Game",
    "UnitDefs", "UnitDefNames", "FeatureDefs", "FeatureDefNames",
    "WeaponDefs", "WeaponDefNames", "LOG", "KEYSYMS", "CMD", "Script",
    "SendToUnsynced", "Platform", "include",
    -- Gadgets
    "GG", "gadgetHandler", "gadget",
    -- Widgets
    "WG", "widgetHandler", "widget",
    -- Libs
    "LCS", "Path", "Table", "Log", "String", "Shaders", "Time", "Array", "StartScript",
    -- SB speciifc
    "SB", "SB_DIR", "gfx",

    -- SB view fields
    "UnitField", "FeatureField", "AreaField", "TriggerField", "UnitTypeField", "FeatureTypeField",
    "TeamField", "NumericField", "StringField", "BooleanField", "NumericComparisonField", "IdentityComparisonField",
    "PositionField"
}