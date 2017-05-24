TerrainPanel = AbstractMainWindowPanel:extends{}

function TerrainPanel:init()
    self:super("init")
    local btnModifyHeightMap = TabbedPanelButton({
        tooltip = "Modify heightmap",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Terrain" }),
        },
        OnClick = {
            function()
                if SB.heightmapEditorView == nil then
                    self.heightmapEditorView = HeightmapEditorView()
                    SB.heightmapEditorView = self.heightmapEditorView
                end
                if SB.heightmapEditorView.window.hidden then
					SB.view:SetMainPanel(SB.heightmapEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyHeightMap)

    local btnModifyTextureMap = TabbedPanelButton({
        tooltip = "Change texture",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Texture" }),
        },
        OnClick = {
            function()
                if SB.terrainEditorView == nil then
                    self.terrainEditorView = TerrainEditorView()
                    SB.terrainEditorView = self.terrainEditorView
                end
                if SB.terrainEditorView.window.hidden then
					SB.view:SetMainPanel(SB.terrainEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyTextureMap)

    local btnModifyGrass = TabbedPanelButton({
        tooltip = "Change grass map",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Grass" }),
        },
        OnClick = {
            function()
                if SB.grassEditorView == nil then
                    self.grassEditorView = GrassEditorView()
                    SB.grassEditorView = self.grassEditorView
                end
                if SB.grassEditorView.window.hidden then
					SB.view:SetMainPanel(SB.grassEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyGrass)

    local btnModifyMetal = TabbedPanelButton({
        tooltip = "Change metal map",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Metal" }),
        },
        OnClick = {
            function()
                if SB.metalEditorView == nil then
                    self.metalEditorView = MetalEditorView()
                    SB.metalEditorView = self.metalEditorView
                end
                if SB.metalEditorView.window.hidden then
					SB.view:SetMainPanel(SB.metalEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyMetal)
	
	local btnTerrainSettings = TabbedPanelButton({
        tooltip = "Change map settings",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Settings" }),
        },
        OnClick = {
            function()
                if SB.terrainSettingsView == nil then
                    self.terrainSettingsView = TerrainSettingsView()
                    SB.terrainSettingsView = self.terrainSettingsView
                end
                if SB.terrainSettingsView.window.hidden then
					SB.view:SetMainPanel(SB.terrainSettingsView.window)
                end
            end
        },
    })
    self.control:AddChild(btnTerrainSettings)
end
