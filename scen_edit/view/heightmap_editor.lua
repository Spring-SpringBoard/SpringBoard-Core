HeightmapEditorView = LCS.class{}

function HeightmapEditorView:init()
    self.fields = {}

    self.heightmapBrushes = ImageListView:New {
        dir = SCEN_EDIT_IMG_DIR .. "resources/brush_patterns/height",
        width = "100%",
        height = "100%",
        multiSelect = false,
    }
    -- FIXME: implement a button for entering the mode instead of image selection
    self.heightmapBrushes.OnSelectItem = {
        function(obj, itemIdx, selected)
            -- FIXME: shouldn't be using ._dirsNum probably
            if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
                local item = self.heightmapBrushes.items[itemIdx]
                self.paintTexture = item
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(TerrainShapeModifyState) then
                    currentState.paintTexture = item
                end
            end
        end
    }
    self.heightmapBrushes:Select("peak3.png")
    
    self.btnAddState = TabbedPanelButton({
        x = 10,
        y = 10,
        tooltip = "Increase or decrease (1)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainIncreaseState(self))
            end
        },
    })
    self.btnSmoothState = TabbedPanelButton({
        x = 80,
        y = 10,
        tooltip = "Smooth the terrain (2)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Smooth" }),
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainSmoothState(self))
            end
        },
    })
    self.btnLevelState = TabbedPanelButton({
        x = 150,
        y = 10,
        tooltip = "Level the terrain (3)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Level" }),
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainLevelState(self))
            end
        },
    })
    self.btnChangeHeightRectState = TabbedPanelButton({
        x = 220,
        y = 10,
        tooltip = "Square add the terrain (4)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Square" }),
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainChangeHeightRectState(self))
            end
        },
    })
    self.btnAddShapeState = TabbedPanelButton({
        x = 290,
        y = 10,
        tooltip = "Modify the terrain by choosing one of the special shapes below (5)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Shape" }),
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainShapeModifyState(self))
            end
        },
    })

    self.imgPanel = ScrollPanel:New {
        x = 0, 
        right = 0,
        bottom = 30, 
        y = 180,
        children = { 
            self.heightmapBrushes,
        }
    }
    
    local btnClose = Button:New {
        caption = 'Close',
        width = 100,
        right = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick = { 
            function() 
                self.window:Hide()
                SCEN_EDIT.stateManager:SetState(DefaultState())
            end 
        },
    }

    self.stackPanel = StackPanel:New {
        height = 100,
        y = 100,
        x = 0,
        right = 0,
        centerItems = false,
        itemPadding = {0,0,0,0},
        padding = {0,0,0,0},
        margin = {0,0,0,0},
        itemMargin = {0,0,0,0},
    }

    self:AddNumericProperty({
        name = "size", 
        value = 100, 
        minValue = 10,
        maxValue = 1000,
        title = "Size:",
        tooltip = "Size of the height brush",
    })
    self:AddNumericProperty({
        name = "strength", 
        value = 1,
        minValue = 0.1,
        maxValue = 100,
        title = "Strength:",
        tooltip = "Strength of the height map tool",
    })
    self:UpdateNumericField("size")

    self.window = Window:New {
        parent = screen0,
        x = 600,
        y = 200,
        width = 520,
        height = 550,
        caption = 'Heightmap editor',
        resizable = false,
        children = {
            self.imgPanel,
            self.stackPanel,
            btnClose,
            self.btnAddState,
            self.btnSmoothState,
            self.btnLevelState,
            self.btnChangeHeightRectState,
            self.btnAddShapeState,
        },
        OnDispose = { function() SCEN_EDIT.heightmapEditorView = nil end },
    }
end

function HeightmapEditorView:StoppedEditing()
    self.btnAddState.state.pressed = false
    self.btnAddState:Invalidate()

    self.btnSmoothState.state.pressed = false
    self.btnSmoothState:Invalidate()

    self.btnLevelState.state.pressed = false
    self.btnLevelState:Invalidate()

    self.btnChangeHeightRectState.state.pressed = false
    self.btnChangeHeightRectState:Invalidate()

    self.btnAddShapeState.state.pressed = false
    self.btnAddShapeState:Invalidate()
end

function HeightmapEditorView:StartedEditing()
    SCEN_EDIT.delay(function()
        local currentState = SCEN_EDIT.stateManager:GetCurrentState()
        local btn
        if currentState:is_A(TerrainIncreaseState) then
            btn = self.btnAddState
        elseif currentState:is_A(TerrainChangeHeightRectState) then
            btn = self.btnChangeHeightRectState
        elseif currentState:is_A(TerrainSmoothState) then
            btn = self.btnSmoothState
        elseif currentState:is_A(TerrainLevelState) then
            btn = self.btnLevelState
        elseif currentState:is_A(TerrainShapeModifyState) then
            btn = self.btnAddShapeState
        end
        btn.state.pressed = true
        btn:Invalidate()
    end)
end

function HeightmapEditorView:Select(indx)
    self.heightmapBrushes:Select(indx)
end

function HeightmapEditorView:UpdateNumericField(name, source)
    local field = self.fields[name]

    -- hackzor
    if source ~= field.editBox then
        local v = tostring(field.value)
        v = v:sub(1, math.min(#v, 6))
        field.editBox:SetText(v)
    end
    if source ~= field.trackbar then
        field.trackbar:SetValue(field.value)
    end
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    if currentState:is_A(AbstractHeightmapEditingState) then
        currentState[field.name] = field.value
    end
end

function HeightmapEditorView:SetNumericField(name, value, source)
    local field = self.fields[name]
    if field.inUpdate then
        return
    end
    
    field.inUpdate = true
    value = tonumber(value)
    if value ~= nil and value ~= field.value then
        value = math.min(field.maxValue, value)
        value = math.max(field.minValue, value)
        field.value = value
        self:UpdateNumericField(field.name, source)
    end
    field.inUpdate = nil
end

function HeightmapEditorView:AddNumericProperty(field)
    self.fields[field.name] = field
    local v = tostring(field.value)
    v = v:sub(1, math.min(#v, 6))

    field.label = Label:New {
        caption = field.title,
        x = 1,
        y = 1,
        tooltip = field.tooltip,
    }
    field.editBox = EditBox:New {
        text = v,
        x = 190,
        y = 1,
        width = 120,
        OnTextInput = {
            function() 
                self:SetNumericField(field.name, field.editBox.text, field.editBox)
            end
        },
        OnKeyPress = {
            function() 
                self:SetNumericField(field.name, field.editBox.text, field.editBox)
            end
        },
    }
    field.trackbar = Trackbar:New {
        x = 340,
        y = 1,
        value = field.value,
        min = field.minValue,
        max = field.maxValue,
        step = 0.01,
    }
    field.trackbar.OnChange = {
        function(obj, value)
            self:SetNumericField(field.name, value, obj)
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