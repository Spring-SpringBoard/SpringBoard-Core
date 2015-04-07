MapEditorView = LCS.class{}

function MapEditorView:init(opts)
    self.fields = {}

--     self.btnClose = Button:New {
--         caption = 'Close',
--         width = 100,
--         right = 15,
--         bottom = 1,
--         height = SCEN_EDIT.conf.B_HEIGHT,
--         OnClick = { 
--             function() 
--                 self.window:Hide() 
--                 SCEN_EDIT.stateManager:SetState(DefaultState())
--             end 
--         },
--     }
-- 
--     self.stackPanel = StackPanel:New {
--         y = 0,
--         height = 400,
--         x = 0,
--         right = 0,
--         centerItems = false,
--         itemPadding = {0,0,0,0},
--         padding = {0,0,0,0},
--         margin = {0,0,0,0},
--         itemMargin = {0,0,0,0},
--     }
-- 
--     self.window = Window:New {
--         parent = screen0,
--         x = opts.x,
--         y = opts.y,
--         width = opts.width,
--         height = opts.height,
--         caption = opts.caption,
--         resizable = true,
--         children = {
--             self.tabPanel,
--             ScrollPanel:New {
--                 x = 0,
--                 y = "50%",
--                 bottom = 30,
--                 right = 0,
--                 borderColor = {0,0,0,0},
--                 horizontalScrollbar = false,
--                 children = { self.stackPanel },
--             },
--             btnClose,
--         },
--     }
end

-- needs to be implemented
function MapEditorView:IsValidTest(state)
    return false
end
--[[
function MapEditorView:Select(indx)
    self.textureImages:Select(indx)
end]]

function MapEditorView:UpdateChoiceField(name)
    local field = self.fields[name]
--[[
    field.comboBox.text = tostring(field.value)
    field.editBox:Invalidate()
    ]]
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    if self:IsValidTest(currentState) then
        currentState[field.name] = field.value
    end
end

function MapEditorView:SetChoiceField(name, value)
    local field = self.fields[name]
    if value ~= nil and value ~= field.value then
        field.value = value
        self:UpdateChoiceField(field.name)
    end
end

function MapEditorView:AddChoiceProperty(field)
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

function MapEditorView:UpdateNumericField(name, source)
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
    if self:IsValidTest(currentState) then
        currentState[field.name] = field.value
    end
end

function MapEditorView:SetNumericField(name, value, source)
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

function MapEditorView:AddNumericProperty(field)
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

function MapEditorView:UpdateColorbarsField(name, source)
    local field = self.fields[name]

    if source ~= field.colorbars then
        field.colorbars:SetColor(field.value)
    end
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    if self:IsValidTest(currentState) then
        currentState[field.name] = field.value
    end
end

function MapEditorView:SetColorbarsField(name, value, source)
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

function MapEditorView:AddColorbarsProperty(field)
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