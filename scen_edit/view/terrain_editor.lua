TerrainEditorView = LCS.class{}

function TerrainEditorView:init()
    local textureImages = ImageListView:New {
        dir = SCEN_EDIT_IMG_DIR .. "brush_textures/",
        width = "100%",
        height = "100%",
		multiSelect = false,
    }
    textureImages.OnSelectItem = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
                local item = textureImages.items[itemIdx]
                self.paintTexture = item
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(TerrainChangeTextureState) then
                    currentState.paintTexture = item
                else
                    SCEN_EDIT.stateManager:SetState(TerrainChangeTextureState(self.paintTexture, textureImages))
                end
            end
			if not selected then
				SCEN_EDIT.stateManager:SetState(DefaultState())
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
            ScrollPanel:New {
                width = '100%',
                height = "100%",
                children = { 
                    textureImages,
                }
            },
        }
    }
end
