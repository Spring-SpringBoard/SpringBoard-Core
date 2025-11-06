-- RmlUi Editor Components (100% Programmatic)
-- ALL editors use the SAME generic_editor.rml template
-- Content is populated dynamically via AddField() API

-- ALL EDITORS extend RmlUiEditorBase and use the generic template
-- They differ only in which fields they add programmatically

-- General Windows
RmlUiScenarioInfoView = RmlUiEditorBase:extends{}
function RmlUiScenarioInfoView:init()
    self:super("init")
    self.editorTitle = "Scenario Info"
    -- TODO in implementation: Add fields
    -- self:AddField(StringField({name="name", title="Name"}))
    -- self:AddField(StringField({name="description", title="Description"}))
end

RmlUiDiplomacyWindow = RmlUiEditorBase:extends{}
function RmlUiDiplomacyWindow:init()
    self:super("init")
    self.editorTitle = "Diplomacy"
end

RmlUiPlayerWindow = RmlUiEditorBase:extends{}
function RmlUiPlayerWindow:init()
    self:super("init")
    self.editorTitle = "Player"
end

RmlUiPlayersWindow = RmlUiEditorBase:extends{}
function RmlUiPlayersWindow:init()
    self:super("init")
    self.editorTitle = "Players"
end

-- Map Editors
RmlUiGrassEditor = RmlUiEditorBase:extends{}
function RmlUiGrassEditor:init()
    self:super("init")
    self.editorTitle = "Grass Editor"
end

RmlUiMetalEditor = RmlUiEditorBase:extends{}
function RmlUiMetalEditor:init()
    self:super("init")
    self.editorTitle = "Metal Map Editor"
end

RmlUiWaterEditor = RmlUiEditorBase:extends{}
function RmlUiWaterEditor:init()
    self:super("init")
    self.editorTitle = "Water Settings"
end

RmlUiLightingEditor = RmlUiEditorBase:extends{}
function RmlUiLightingEditor:init()
    self:super("init")
    self.editorTitle = "Lighting Settings"
end

RmlUiSkyEditor = RmlUiEditorBase:extends{}
function RmlUiSkyEditor:init()
    self:super("init")
    self.editorTitle = "Sky Settings"
end

RmlUiTerrainSettingsEditor = RmlUiEditorBase:extends{}
function RmlUiTerrainSettingsEditor:init()
    self:super("init")
    self.editorTitle = "Terrain Settings"
end

RmlUiDNTSEditor = RmlUiEditorBase:extends{}
function RmlUiDNTSEditor:init()
    self:super("init")
    self.editorTitle = "DNTS Editor"
end

RmlUiMaterialBrowser = RmlUiEditorBase:extends{}
function RmlUiMaterialBrowser:init()
    self:super("init")
    self.editorTitle = "Material Browser"
end

-- Object Components
RmlUiAnimationsView = RmlUiEditorBase:extends{}
function RmlUiAnimationsView:init()
    self:super("init")
    self.editorTitle = "Animations"
end

RmlUiCollisionWindow = RmlUiEditorBase:extends{}
function RmlUiCollisionWindow:init()
    self:super("init")
    self.editorTitle = "Collision Volume"
end

RmlUiObjectDefsPanel = RmlUiEditorBase:extends{}
function RmlUiObjectDefsPanel:init()
    self:super("init")
    self.editorTitle = "Object Definitions"
end

RmlUiObjectPropertyWindow = RmlUiEditorBase:extends{}
function RmlUiObjectPropertyWindow:init()
    self:super("init")
    self.editorTitle = "Object Properties"
end

-- Trigger Components
RmlUiTriggerWindow = RmlUiEditorBase:extends{}
function RmlUiTriggerWindow:init()
    self:super("init")
    self.editorTitle = "Edit Trigger"
end

RmlUiEventWindow = RmlUiEditorBase:extends{}
function RmlUiEventWindow:init()
    self:super("init")
    self.editorTitle = "Edit Event"
end

RmlUiConditionWindow = RmlUiEditorBase:extends{}
function RmlUiConditionWindow:init()
    self:super("init")
    self.editorTitle = "Edit Condition"
end

RmlUiActionWindow = RmlUiEditorBase:extends{}
function RmlUiActionWindow:init()
    self:super("init")
    self.editorTitle = "Edit Action"
end

RmlUiAreasWindow = RmlUiEditorBase:extends{}
function RmlUiAreasWindow:init()
    self:super("init")
    self.editorTitle = "Areas"
end

RmlUiAreaView = RmlUiEditorBase:extends{}
function RmlUiAreaView:init()
    self:super("init")
    self.editorTitle = "Area"
end

RmlUiVariablesWindow = RmlUiEditorBase:extends{}
function RmlUiVariablesWindow:init()
    self:super("init")
    self.editorTitle = "Variables"
end

RmlUiVariableWindow = RmlUiEditorBase:extends{}
function RmlUiVariableWindow:init()
    self:super("init")
    self.editorTitle = "Edit Variable"
end

RmlUiDebugTriggerView = RmlUiEditorBase:extends{}
function RmlUiDebugTriggerView:init()
    self:super("init")
    self.editorTitle = "Debug Triggers"
end

RmlUiDebugVariableView = RmlUiEditorBase:extends{}
function RmlUiDebugVariableView:init()
    self:super("init")
    self.editorTitle = "Debug Variables"
end

RmlUiCustomWindow = RmlUiEditorBase:extends{}
function RmlUiCustomWindow:init()
    self:super("init")
    self.editorTitle = "Custom Trigger Code"
end

-- Dialog Variants (these DO have RML - they're modal dialogs with specific layouts)
RmlUiImportFileDialog = RmlUiBaseDialog:extends{}
function RmlUiImportFileDialog:init(opts)
    opts = opts or {}
    opts.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/dialogs/import_file_dialog.rml')
    opts.title = opts.title or "Import File"
    RmlUiBaseDialog.init(self, opts)
end

RmlUiExportFileDialog = RmlUiBaseDialog:extends{}
function RmlUiExportFileDialog:init(opts)
    opts = opts or {}
    opts.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/dialogs/export_file_dialog.rml')
    opts.title = opts.title or "Export File"
    RmlUiBaseDialog.init(self, opts)
end

RmlUiOpenProjectDialog = RmlUiBaseDialog:extends{}
function RmlUiOpenProjectDialog:init(opts)
    opts = opts or {}
    opts.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/dialogs/open_project_dialog.rml')
    opts.title = opts.title or "Open Project"
    RmlUiBaseDialog.init(self, opts)
end

RmlUiSaveProjectDialog = RmlUiBaseDialog:extends{}
function RmlUiSaveProjectDialog:init(opts)
    opts = opts or {}
    opts.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/dialogs/save_project_dialog.rml')
    opts.title = opts.title or "Save Project"
    RmlUiBaseDialog.init(self, opts)
end
