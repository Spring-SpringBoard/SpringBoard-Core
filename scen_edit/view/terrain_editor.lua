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
    local btnClose = Button:New {
        caption='Close',
        width=100,
        right = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick = { 
            function() 
                self.window:Dispose() 
				SCEN_EDIT.stateManager:SetState(DefaultState())
            end 
        },
    }
    local lblNote = Label:New {
        caption="\255\255\255\0Saving textures is currently slow.\b",
        x = 1,
        bottom = 5,
    }

    self.window = Window:New {
        parent = screen0,
        x = 300,
        y = 400,
        width = 440,    
        height = 400,
        caption = 'Texture editor',
        children = {
            ScrollPanel:New {
                width = '100%',
                height = "100%",
                y = 15,
                bottom = 40,
                children = { 
                    textureImages,
                }
            },
            btnClose,
            lblNote,
        }
    }
end
