-- Generic RmlUi Component Stubs
-- This file contains stub implementations for all RmlUi components

-- Base Component Class
RmlUiComponent = LCS.class{}

function RmlUiComponent:init(rmlPath, componentName)
    self.rmlPath = rmlPath
    self.componentName = componentName or "Component"
    self.document = nil
end

function RmlUiComponent:Initialize()
    if not self.rmlPath then
        Log.Error("No RML path specified for " .. self.componentName)
        return false
    end

    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    if not self.document then
        Log.Error("Failed to load RML document: " .. self.rmlPath)
        return false
    end

    self:BindEvents()
    Log.Notice(self.componentName .. " initialized (RmlUi stub)")
    return true
end

function RmlUiComponent:BindEvents()
    -- Override in subclass
end

function RmlUiComponent:Show()
    if self.document then
        self.document:Show()
    end
end

function RmlUiComponent:Hide()
    if self.document then
        self.document:Hide()
    end
end

function RmlUiComponent:Close()
    if self.document then
        self.document:Close()
        self.document = nil
    end
end

-- General Windows
RmlUiScenarioInfoView = LCS.class{}
function RmlUiScenarioInfoView:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/general/scenario_info.rml')
end
function RmlUiScenarioInfoView:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    Log.Notice("Scenario Info initialized (RmlUi stub)")
    return true
end

RmlUiDiplomacyWindow = RmlUiComponent:extends{}
function RmlUiDiplomacyWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/general/diplomacy.rml'), "Diplomacy")
end

RmlUiPlayerWindow = RmlUiComponent:extends{}
function RmlUiPlayerWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/general/player.rml'), "Player")
end

RmlUiPlayersWindow = RmlUiComponent:extends{}
function RmlUiPlayersWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/general/players.rml'), "Players")
end

-- Map Editors
RmlUiGrassEditor = RmlUiComponent:extends{}
function RmlUiGrassEditor:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/map/grass_editor.rml'), "Grass Editor")
end

RmlUiMetalEditor = RmlUiComponent:extends{}
function RmlUiMetalEditor:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/map/metal_editor.rml'), "Metal Editor")
end

RmlUiWaterEditor = RmlUiComponent:extends{}
function RmlUiWaterEditor:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/map/water_editor.rml'), "Water Editor")
end

RmlUiLightingEditor = RmlUiComponent:extends{}
function RmlUiLightingEditor:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/map/lighting_editor.rml'), "Lighting Editor")
end

RmlUiSkyEditor = RmlUiComponent:extends{}
function RmlUiSkyEditor:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/map/sky_editor.rml'), "Sky Editor")
end

RmlUiTerrainSettingsEditor = RmlUiComponent:extends{}
function RmlUiTerrainSettingsEditor:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/map/terrain_settings.rml'), "Terrain Settings")
end

RmlUiDNTSEditor = RmlUiComponent:extends{}
function RmlUiDNTSEditor:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/map/dnts_editor.rml'), "DNTS Editor")
end

RmlUiMaterialBrowser = RmlUiComponent:extends{}
function RmlUiMaterialBrowser:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/map/material_browser.rml'), "Material Browser")
end

-- Object Components
RmlUiAnimationsView = RmlUiComponent:extends{}
function RmlUiAnimationsView:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/object/animations.rml'), "Animations")
end

RmlUiCollisionWindow = RmlUiComponent:extends{}
function RmlUiCollisionWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/object/collision.rml'), "Collision")
end

RmlUiObjectDefsPanel = RmlUiComponent:extends{}
function RmlUiObjectDefsPanel:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/object/object_defs_panel.rml'), "Object Defs Panel")
end

RmlUiObjectPropertyWindow = RmlUiComponent:extends{}
function RmlUiObjectPropertyWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/object/object_property.rml'), "Object Properties")
end

-- Trigger Components
RmlUiTriggerWindow = RmlUiComponent:extends{}
function RmlUiTriggerWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/trigger/trigger_window.rml'), "Trigger Window")
end

RmlUiEventWindow = RmlUiComponent:extends{}
function RmlUiEventWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/trigger/event_window.rml'), "Event Window")
end

RmlUiConditionWindow = RmlUiComponent:extends{}
function RmlUiConditionWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/trigger/condition_window.rml'), "Condition Window")
end

RmlUiActionWindow = RmlUiComponent:extends{}
function RmlUiActionWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/trigger/action_window.rml'), "Action Window")
end

RmlUiAreasWindow = RmlUiComponent:extends{}
function RmlUiAreasWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/trigger/areas.rml'), "Areas")
end

RmlUiAreaView = RmlUiComponent:extends{}
function RmlUiAreaView:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/trigger/area_view.rml'), "Area View")
end

RmlUiVariablesWindow = RmlUiComponent:extends{}
function RmlUiVariablesWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/trigger/variables.rml'), "Variables")
end

RmlUiVariableWindow = RmlUiComponent:extends{}
function RmlUiVariableWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/trigger/variable_window.rml'), "Variable Window")
end

RmlUiDebugTriggerView = RmlUiComponent:extends{}
function RmlUiDebugTriggerView:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/trigger/debug_trigger.rml'), "Debug Triggers")
end

RmlUiDebugVariableView = RmlUiComponent:extends{}
function RmlUiDebugVariableView:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/trigger/debug_variable.rml'), "Debug Variables")
end

RmlUiCustomWindow = RmlUiComponent:extends{}
function RmlUiCustomWindow:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/trigger/custom_window.rml'), "Custom Window")
end

-- Dialog Variants
RmlUiImportFileDialog = RmlUiComponent:extends{}
function RmlUiImportFileDialog:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/dialogs/import_file_dialog.rml'), "Import File Dialog")
end

RmlUiExportFileDialog = RmlUiComponent:extends{}
function RmlUiExportFileDialog:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/dialogs/export_file_dialog.rml'), "Export File Dialog")
end

RmlUiOpenProjectDialog = RmlUiComponent:extends{}
function RmlUiOpenProjectDialog:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/dialogs/open_project_dialog.rml'), "Open Project Dialog")
end

RmlUiSaveProjectDialog = RmlUiComponent:extends{}
function RmlUiSaveProjectDialog:init()
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/dialogs/save_project_dialog.rml'), "Save Project Dialog")
end
