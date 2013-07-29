TerrainPanel = AbstractMainWindowPanel:extends{}

function TerrainPanel:init()
	self:super("init")
	local btnModifyHeightMap = Button:New {
        caption = "",
        tooltip = "Modify heightmap",
        width = 80,
        height = 80,
        children = {
            Image:New {                                 
                file = SCEN_EDIT_IMG_DIR .. "terrain_height.png",
				height = 40, 
				width = 40,
                margin = {0, 0, 0, 0},
				x = 10,
            },
			Label:New {
				caption = "Heightmap",
				y = 40,
			},
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainIncreaseState())
            end
        },
    }
	self.control:AddChild(btnModifyHeightMap)
	
    self.paintTexture = SCEN_EDIT_IMG_DIR .. "brush_textures/grass.png"
    
    local btnModifyTextureMap = Button:New {
        caption = "",
        tooltip = "Change texture",
        width = 80,
        height = 80,
        children = {
            Image:New {                                 
                file=SCEN_EDIT_IMG_DIR .. "terrain_texture.png", 
				height = 40, 
				width = 40,
                margin = {0, 0, 0, 0},
				x = 10,
            },
			Label:New {
				caption = "Texture",
				y = 40,
				x = 5,
			},
        },
        OnClick = {
            function()
                self.terrainEditorView = TerrainEditorView()
            end
        },
    }	
	self.control:AddChild(btnModifyTextureMap)
end