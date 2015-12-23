TerrainPanel = AbstractMainWindowPanel:extends{}

function TerrainPanel:init()
    self:super("init")
    local btnModifyHeightMap = TabbedPanelButton({
        tooltip = "Modify heightmap",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Terrain" }),
        },
        OnClick = {
            function()
                if SCEN_EDIT.heightmapEditorView == nil then
                    self.heightmapEditorView = HeightmapEditorView()
                    SCEN_EDIT.heightmapEditorView = self.heightmapEditorView
                end
                if SCEN_EDIT.heightmapEditorView.window.hidden then
					SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.heightmapEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyHeightMap)

    local btnModifyTextureMap = TabbedPanelButton({
        tooltip = "Change texture",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Texture" }),
        },
        OnClick = {
            function()
                if SCEN_EDIT.terrainEditorView == nil then
                    self.terrainEditorView = TerrainEditorView()
                    SCEN_EDIT.terrainEditorView = self.terrainEditorView
                end
                if SCEN_EDIT.terrainEditorView.window.hidden then
					SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.terrainEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyTextureMap)

    local btnModifyGrass = TabbedPanelButton({
        tooltip = "Change grass map",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Grass" }),
        },
        OnClick = {
            function()
                if SCEN_EDIT.grassEditorView == nil then
                    self.grassEditorView = GrassEditorView()
                    SCEN_EDIT.grassEditorView = self.grassEditorView
                end
                if SCEN_EDIT.grassEditorView.window.hidden then
					SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.grassEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyGrass)

    local btnModifyMetal = TabbedPanelButton({
        tooltip = "Change metal map",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Metal" }),
        },
        OnClick = {
            function()
                if SCEN_EDIT.metalEditorView == nil then
                    self.metalEditorView = MetalEditorView()
                    SCEN_EDIT.metalEditorView = self.metalEditorView
                end
                if SCEN_EDIT.metalEditorView.window.hidden then
					SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.metalEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyMetal)
	
	local btnTerrainSettings = TabbedPanelButton({
        tooltip = "Change map settings",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Settings" }),
        },
        OnClick = {
            function()
                if SCEN_EDIT.terrainSettingsView == nil then
                    self.terrainSettingsView = TerrainSettingsView()
                    SCEN_EDIT.terrainSettingsView = self.terrainSettingsView
                end
                if SCEN_EDIT.terrainSettingsView.window.hidden then
					SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.terrainSettingsView.window)
                end
            end
        },
    })
    self.control:AddChild(btnTerrainSettings)
end
