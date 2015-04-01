TerrainEditorView = LCS.class{}

function TerrainEditorView:init()
    self.fields = {}

    self.textureImages = ImageListView:New {
        dir = SCEN_EDIT_IMG_DIR .. "resources/brush_textures/",
        width = "100%",
        height = "100%",
        multiSelect = false,
        iconX = 48,
        iconY = 48,
    }
    -- FIXME: implement a button for entering the mode instead of image selection
    self.textureImages.OnSelectItem = {
        function(obj, itemIdx, selected)
            -- FIXME: shouldn't be using ._dirsNum probably
            if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
                local item = self.textureImages.items[itemIdx]
                self.paintTexture = item
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(TerrainChangeTextureState) then
                    currentState.paintTexture = item
                else
                    SCEN_EDIT.stateManager:SetState(TerrainChangeTextureState(self))
                end
            end
            -- FIXME: disallow deselection
--             if not selected then
--                 local currentState = SCEN_EDIT.stateManager:GetCurrentState()
--                 SCEN_EDIT.stateManager:SetState(DefaultState())
--             end
        end
    }

    self.detailTextureImages = ImageListView:New {
        dir = SCEN_EDIT_IMG_DIR .. "resources/brush_patterns/detail/",
        width = "100%",
        height = "100%",
        multiSelect = false,
        iconX = 48,
        iconY = 48,
    }
    self.detailTextureImages.OnSelectItem = {
        function(obj, itemIdx, selected)
            -- FIXME: shouldn't be using ._dirsNum probably
            if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
                local item = self.detailTextureImages.items[itemIdx]
                self.penTexture = item
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(TerrainChangeTextureState) then
                    currentState.penTexture = item
                end
            end
        end
    }
    self.detailTextureImages:Select("detailtex.bmp")

    self.tabPanel = Chili.TabPanel:New {
        x = 0, 
        right = 0,
        y = 20, 
        height = "49%",
        padding = {0, 0, 0, 0},
        tabs = { {
                name = "Brush",
                children = {
                    ScrollPanel:New {
                        x = 1,
                        right = 1,
                        y = 15,
                        bottom = 0,
                        children = { 
                            self.textureImages,
                        }
                    },
                },
            }, {
                name = "Detail", 
                children = { 
                    ScrollPanel:New {
                        x = 1,
                        right = 1,
                        y = 15,
                        bottom = 0,
                        children = { 
                            self.detailTextureImages 
                        },
                    },
                },
            }
        },
    }

    local btnClose = Button:New {
        caption = 'Close',
        width = 100,
        right = 15,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick = { 
            function() 
                self.window:Hide() 
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
        y = 0,
        height = 400,
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
        maxValue = 5000, 
        title = "Size:",
        tooltip = "Size of the paint brush",
    })
    self:AddNumericProperty({
        name = "texScale", 
        value = 2, 
        minValue = 0.2, 
        maxValue = 8, 
        title = "Texture scale:",
        tooltip = "Texture sampling rate (larger number means higher frequency)",
    })
    self:AddNumericProperty({
        name = "texOffsetX", 
        value = 0, 
        minValue = -1024, 
        maxValue = 1024, 
        title = "Texture offset X:",
        tooltip = "Texture offset X",
    })
    self:AddNumericProperty({
        name = "texOffsetY", 
        value = 0, 
        minValue = -1024, 
        maxValue = 1024, 
        title = "Texture offset Y:",
        tooltip = "Texture offset Y",
    })
    self:AddNumericProperty({
        name = "detailTexScale", 
        value = 0.2, 
        minValue = 0.01, 
        maxValue = 1, 
        title = "Detail texture scale:",
        tooltip = "Detail texture sampling rate (larger number means higher frequency)",
    })
    self:AddNumericProperty({
        name = "blendFactor", 
        value = 1, 
        minValue = 0.0, 
        maxValue = 1, 
        title = "Blend factor:",
        tooltip = "Proportion of texture to be applied",
    })
    self:AddNumericProperty({
        name = "falloffFactor", 
        value = 0.3, 
        minValue = 0.0, 
        maxValue = 1, 
        title = "Falloff factor:",
        tooltip = "Texture painting fade out (1 means crisp)",
    })
    self:AddNumericProperty({
        name = "featureFactor", 
        value = 1, 
        minValue = 0.0, 
        maxValue = 1, 
        title = "Feature factor:",
        tooltip = "Feature filtering (1 means no filter filtering)",
    })
    self:AddChoiceProperty({
        name = "mode", 
        items = {
            "Normal",
            "Darken",
            "Lighten",
            "SoftLight",
            "HardLight",
            "Luminance",
            "Multiply",
            "Premultiplied",
            "Overlay",
            "Screen",
            "Add",
            "Subtract",
            "Difference",
            "InverseDifference",
            "Exclusion",
            "Color",
            "ColorBurn",
            "ColorDodge",
        },
        title = "Mode:"
    })
    self:AddColorbarsProperty({
        name = "diffuseColor",
        title = "Color: ",
        value = {1,1,1,1},
    })
    self:UpdateNumericField("size")
    self:UpdateChoiceField("mode")
    self:UpdateColorbarsField("diffuseColor")

    self.window = Window:New {
        parent = screen0,
        x = 50,
        y = 200,
        width = 410,
        height = 600,
        caption = 'Texture editor',
        resizable = true,
        children = {
            self.tabPanel,
            ScrollPanel:New {
                x = 0,
                y = "50%",
                bottom = 30,
                right = 0,
                borderColor = {0,0,0,0},
                horizontalScrollbar = false,
                children = { self.stackPanel },
            },
            btnClose,
            lblNote,
        },
        OnDispose = { function() SCEN_EDIT.terrainEditorView = nil end },
    }
end

function TerrainEditorView:Select(indx)
    self.textureImages:Select(indx)
end

function TerrainEditorView:UpdateChoiceField(name)
    local field = self.fields[name]
--[[
    field.comboBox.text = tostring(field.value)
    field.editBox:Invalidate()
    ]]
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    if currentState:is_A(TerrainChangeTextureState) then
        currentState[field.name] = field.value
    end
end

function TerrainEditorView:SetChoiceField(name, value)
    local field = self.fields[name]
    if value ~= nil and value ~= field.value then
        field.value = value
        self:UpdateChoiceField(field.name)
    end
end

function TerrainEditorView:AddChoiceProperty(field)
    self.fields[field.name] = field

    field.label = Label:New {
        caption = field.title,
        x = 1,
        y = 10,
    }
    field.comboBox = ComboBox:New {
        x = 130,
        y = 0,
        width = 150,
        height = 30,
        items = field.items,
    }
    field.comboBox.OnSelect = {
        function(obj, indx)
            local value = field.comboBox.items[indx]
            self:SetChoiceField(field.name, value)
        end
    }
    field.value = field.items[1]

    local ctrl = Control:New {
        x = 0,
        y = 0,
        width = 300,
        height = 20,
        padding = {0, 0, 0, 0},
        children = {
            field.label,
            field.comboBox,
        }
    }
    self.stackPanel:AddChild(ctrl)
end

function TerrainEditorView:UpdateNumericField(name, source)
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
    if currentState:is_A(TerrainChangeTextureState) then
        currentState[field.name] = field.value
    end
end

function TerrainEditorView:SetNumericField(name, value, source)
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

function TerrainEditorView:AddNumericProperty(field)
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
        x = 140,
        y = 1,
        width = 80,
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
        x = 250,
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
        width = 400,
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

function TerrainEditorView:UpdateColorbarsField(name, source)
    local field = self.fields[name]

    if source ~= field.colorbars then
        field.colorbars:SetColor(field.value)
    end
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    if currentState:is_A(TerrainChangeTextureState) then
        currentState[field.name] = field.value
    end
end

function TerrainEditorView:SetColorbarsField(name, value, source)
    local field = self.fields[name]
    if field.inUpdate then
        return
    end
    field.inUpdate = true

    if value ~= field.value then
        field.value = value
        self:UpdateColorbarsField(field.name, source)
    end
    field.inUpdate = nil
end

function TerrainEditorView:AddColorbarsProperty(field)
    self.fields[field.name] = field

    field.label = Label:New {
        caption = field.title,
        x = 1,
        y = 1,
        tooltip = field.tooltip,
    }
    field.colorbars = Colorbars:New {
        color = field.value,
        x = 130,
        y = 1,
        width = 225,
        height = 40,
        OnChange = {
            function(obj, value)
                self:SetColorbarsField(field.name, value, obj)
            end
        },
    }
    local ctrl = Control:New {
        x = 0,
        y = 0,
        width = 300,
        height = 40,
        padding = {0, 0, 0, 0},
        children = {
            field.label,
            field.colorbars,
        }
    }
    self.stackPanel:AddChild(ctrl)
end