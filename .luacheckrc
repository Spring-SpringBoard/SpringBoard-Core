
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
    "LCS", "Path", "Table", "Log", "String", "Shaders", "Time", "Array", "StartScript",
    -- SB speciifc
    "SB", "gfx",

    -- SB view fields
    "UnitField", "FeatureField", "AreaField", "TriggerField", "UnitTypeField", "FeatureTypeField",
    "TeamField", "NumericField", "StringField", "BooleanField", "NumericComparisonField", "IdentityComparisonField",
    "PositionField",

    -- RmlUi core
    "RmlUiManager", "RmlUiBuilder", "RmlUiEditorBase", "RmlUiComponent",

    -- RmlUi fields
    "RmlUiField", "RmlUiStringField", "RmlUiNumericField", "RmlUiBooleanField", "RmlUiChoiceField",
    "RmlUiColorField", "RmlUiAssetField", "RmlUiMaterialField", "RmlUiObjectField", "RmlUiObjectTypeField",
    "RmlUiTeamField", "RmlUiArrayField", "RmlUiGroupField",

    -- RmlUi field compat (overwrites StringField, etc.)
    "ChoiceField", "ColorField", "AssetField", "MaterialField", "ObjectField", "ObjectTypeField", "ArrayField", "GroupField",

    -- RmlUi pickers
    "RmlUiAssetPickerWindow", "RmlUiColorPickerWindow", "RmlUiMaterialPickerWindow",
    "AssetPickerWindow", "ColorPickerWindow", "MaterialPickerWindow",

    -- RmlUi dialogs
    "RmlUiBaseDialog", "RmlUiFileDialog", "RmlUiNewProjectDialog",
    "RmlUiImportFileDialog", "RmlUiExportFileDialog", "RmlUiOpenProjectDialog", "RmlUiSaveProjectDialog",

    -- RmlUi editors
    "RmlUiTriggerEditor", "RmlUiObjectEditor", "RmlUiHeightmapEditor", "RmlUiTextureEditor",
    "RmlUiGrassEditor", "RmlUiMetalEditor", "RmlUiWaterEditor", "RmlUiLightingEditor",
    "RmlUiSkyEditor", "RmlUiTerrainSettingsEditor", "RmlUiDNTSEditor", "RmlUiMaterialBrowser",

    -- RmlUi floating windows
    "RmlUiCommandWindow", "RmlUiStatusWindow", "RmlUiControlButtons", "RmlUiTopLeftMenu",

    -- RmlUi general windows
    "RmlUiScenarioInfoView", "RmlUiDiplomacyWindow", "RmlUiPlayerWindow", "RmlUiPlayersWindow",

    -- RmlUi object components
    "RmlUiAnimationsView", "RmlUiCollisionWindow", "RmlUiObjectDefsPanel", "RmlUiObjectPropertyWindow",

    -- RmlUi trigger components
    "RmlUiTriggerWindow", "RmlUiEventWindow", "RmlUiConditionWindow", "RmlUiActionWindow",
    "RmlUiAreasWindow", "RmlUiAreaView", "RmlUiVariablesWindow", "RmlUiVariableWindow",
    "RmlUiDebugTriggerView", "RmlUiDebugVariableView", "RmlUiCustomWindow"
}