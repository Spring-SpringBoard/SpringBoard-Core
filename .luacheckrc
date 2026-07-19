
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

files["libs_sb/utils/luaunit.lua"] = { ignore = {"581"} }

-- Third-party code bundled into the tree (git submodules, vendored libraries,
-- Chili UI skins, engine widgets/gadgets). Not SBC editor source, so not linted.
exclude_files = {
    -- Generated distributions and build outputs may contain engine Lua files.
    "artifacts/**",
    "libs_sb/chiliui/**",
    "libs_sb/chonsole/**",
    "libs_sb/s11n/**",
    "libs_sb/spring-launcher/**",
    "libs_sb/i18n/**",
    "libs_sb/kernel/**",
    "libs_sb/lcs/**",
    "libs_sb/springmon/**",
    "libs_sb/chilifx/**",
    "libs_sb/chotify/**",
    "libs_sb/json.lua",
    "libs_sb/MessagePack.lua",
    "libs_sb/savetable.lua",
    "LuaUI/Configs/chili/**",
    "LuaUI/Configs/chilitip_conf.lua",
    "LuaUI/widgets/gui_chili_selections_and_cursortip.lua",
    "LuaUI/widgets/hide_default_layout.lua",
    "LuaRules/Configs/icon_generator.lua",
    "LuaRules/Gadgets/unit_icongenerator.lua",
}

globals = {
    -- std extensions
    "math.round", "math.bit_or",
    "table.ifind", "table.show", "table.save", "table.echo", "table.print",
    -- Spring
    "Spring", "VFS", "gl", "GL", "Game",
    "UnitDefs", "UnitDefNames", "FeatureDefs", "FeatureDefNames",
    "WeaponDefs", "WeaponDefNames", "LOG", "KEYSYMS", "CMD", "Script",
    "SendToUnsynced", "Platform", "include",
    "Engine",
    -- Gadgets
    "GG", "gadgetHandler", "gadget",
    -- Widgets
    "WG", "widgetHandler", "widget",
    -- Libs
    "LCS", "Path", "Table", "Log", "String", "Shaders", "Time", "Array", "StartScript", "json",
    -- SB speciifc
    "SB", "gfx",

    -- SB view fields
    "UnitField", "FeatureField", "AreaField", "TriggerField", "UnitTypeField", "FeatureTypeField",
    "TeamField", "NumericField", "StringField", "BooleanField", "NumericComparisonField", "IdentityComparisonField",
    "PositionField"
}
