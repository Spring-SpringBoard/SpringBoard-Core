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
                SCEN_EDIT.stateManager:SetState(TerrainIncreaseState())
            end
        },
    })
	self.control:AddChild(btnModifyHeightMap)
	
    self.paintTexture = SCEN_EDIT_IMG_DIR .. "brush_textures/grass.png"
    
    local btnModifyTextureMap = TabbedPanelButton({
        tooltip = "Change texture",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_texture.png" }),
			TabbedPanelLabel({ caption = "Texture" }),
        },
        OnClick = {
            function()
                self.terrainEditorView = TerrainEditorView()
            end
        },
    })
	self.control:AddChild(btnModifyTextureMap)
end
