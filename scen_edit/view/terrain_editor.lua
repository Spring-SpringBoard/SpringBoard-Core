TerrainEditorView = LCS.class{}

function TerrainEditorView:init()
    self.fields = {}
    
    self.textureImages = ImageListView:New {
        dir = SCEN_EDIT_IMG_DIR .. "brush_textures/",
        width = "100%",
        height = "100%",
		multiSelect = false,
    }
    self.textureImages.OnSelectItem = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
                local item = self.textureImages.items[itemIdx]
                self.paintTexture = item
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(TerrainChangeTextureState) then
                    currentState.paintTexture = item
                else
                    SCEN_EDIT.stateManager:SetState(TerrainChangeTextureState(self))
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
    

    self.stackPanel = StackPanel:New {
        y = 330,
        bottom = 30,
        x = 0,
        right = 0,
        centerItems = false,
    }
    
    self:AddNumericProperty({
        name = "size", 
        value = 100, 
        minValue = 10, 
        maxValue = 1000, 
        title = "Size:"
    })
    self:AddNumericProperty({
        name = "texScale", 
        value = 2, 
        minValue = 0.2, 
        maxValue = 8, 
        title = "Texture scale:"
    })
    self:AddNumericProperty({
        name = "detailTexScale", 
        value = 0.2, 
        minValue = 0.01, 
        maxValue = 1, 
        title = "Detail texture scale:"
    })
    self:UpdateField("size")

    self.window = Window:New {
        parent = screen0,
        x = 300,
        y = 100,
        width = 520,
        height = 700,
        caption = 'Texture editor',
        children = {
            ScrollPanel:New {
                width = '100%',
                height = "100%",
                y = 15,
                bottom = 340,
                children = { 
                    self.textureImages,
                }
            },
            self.stackPanel,
            btnClose,
            lblNote,
        }
    }
end

function TerrainEditorView:Select(indx)
    self.textureImages:Select(indx)
end

function TerrainEditorView:UpdateField(name)
    local field = self.fields[name]
    
    field.editBox.text = tostring(field.value)
    field.editBox:Invalidate()
    field.trackbar.value = field.value
    field.trackbar:Invalidate()
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    if currentState:is_A(TerrainChangeTextureState) then
        currentState[field.name] = field.value
    end
end

function TerrainEditorView:SetField(name, value)
    local field = self.fields[name]
    value = tonumber(value)
    if value ~= nil and value ~= field.value then
        value = math.min(field.maxValue, value)
        value = math.max(field.minValue, value)
        field.value = value
        self:UpdateField(field.name)
    end
end

function TerrainEditorView:AddNumericProperty(field)
    self.fields[field.name] = field

    field.label = Label:New {
        caption = field.title,
        x = 1,
        y = 1,
    }
    field.editBox = EditBox:New {
        text = tostring(field.value),
        x = 170,
        y = 1,
        width = 120,
        OnTextInput = {
            function() 
                self:SetField(field.name, field.editBox.text)
            end
        },
        OnKeyPress = {
            function() 
                self:SetField(field.name, field.editBox.text)
            end
        },
    }
    field.trackbar = Trackbar:New {
        x = 320,
        y = 1,
        value = field.value,
        min = field.minValue,
        max = field.maxValue,
        step = 0.01,
    }
    field.trackbar.OnChange = {
        function(obj, value)
            self:SetField(field.name, value)
        end
    }

    local ctrl = Control:New {
        x = 0,
        y = 0,
        width = 300,
        height = 20,
        padding = {0, 0, 0, 0},
        children = {
            field.label,
            field.editBox,
            field.trackbar,
        }
    }
    self.stackPanel:AddChild(ctrl)
end