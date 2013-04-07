TerrainEditorView = LCS.class{}

function TerrainEditorView:init()
    self.paintTexture = SCEN_EDIT_IMG_DIR .. "brush_textures/grass.png"

    local btnModifyHeightMap = Button:New {
        caption = "",
        tooltip = "Modify heightmap",
        width = SCEN_EDIT.conf.B_HEIGHT + 20,
        height = SCEN_EDIT.conf.B_HEIGHT + 20,
        children = {
            Image:New {                                 
                file=SCEN_EDIT_IMG_DIR .. "terrain_height.png", 
                height = SCEN_EDIT.conf.B_HEIGHT - 2, 
                width = SCEN_EDIT.conf.B_HEIGHT - 2, 
                margin = {0, 0, 0, 0},
            },
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainIncreaseState())
            end
        },
    }
    
    local btnModifyTextureMap = Button:New {
        caption = "",
        tooltip = "Change texture",
        width = SCEN_EDIT.conf.B_HEIGHT + 20,
        height = SCEN_EDIT.conf.B_HEIGHT + 20,
        children = {
            Image:New {                                 
                file=SCEN_EDIT_IMG_DIR .. "terrain_texture.png", 
                height = SCEN_EDIT.conf.B_HEIGHT - 2, 
                width = SCEN_EDIT.conf.B_HEIGHT - 2, 
                margin = {0, 0, 0, 0},
            },
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainChangeTextureState(self.paintTexture))
            end
        },
    }

    local textureImages = ImageListView:New {
        dir = SCEN_EDIT_IMG_DIR .. "brush_textures/",
        width = "100%",
        height = "100%",
    }
    textureImages.OnSelectItem = {
        function(obj, itemIdx, selected)
            Spring.Echo(itemIdx, selected)
            if selected and itemIdx > 0 then
                local item = textureImages.items[itemIdx]
                self.paintTexture = item
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(TerrainChangeTextureState) then
                    currentState.paintTexture = item
                else
                    SCEN_EDIT.stateManager:SetState(TerrainChangeTextureState(self.paintTexture))
                end
            end
        end
    }

	self.terrainEditorWindow = Window:New {
		parent = screen0,
		x = 300,
		y = 400,
		width = 400,	
		height = 400,		
		children = {
			StackPanel:New {
                orientation = 'horizontal',
                width = '100%',
                height = SCEN_EDIT.conf.B_HEIGHT + 40,
                padding = {0,0,0,0},
                itemPadding = {0,10,10,10},
                itemMargin = {0,0,0,0},
                resizeItems = false,
				children = {
                    btnModifyHeightMap,
                    btnModifyTextureMap,
				},
			},
            ScrollPanel:New {
                width = '100%',
                y = SCEN_EDIT.conf.B_HEIGHT + 40,
                bottom = 1,
                children = { 
                    textureImages,
                }
            },
		}
	}
end
