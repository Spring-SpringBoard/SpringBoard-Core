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
                    SCEN_EDIT.heightmapEditorView.window:Show()
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
                    SCEN_EDIT.terrainEditorView.window:Show()
                end
            end
        },
    })
    self.control:AddChild(btnModifyTextureMap)

    local btnModifyTextureMap = TabbedPanelButton({
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
                    SCEN_EDIT.grassEditorView.window:Show()
                end
            end
        },
    })
    self.control:AddChild(btnModifyTextureMap)
end
