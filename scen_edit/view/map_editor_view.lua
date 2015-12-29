MapEditorView = LCS.class{}

function MapEditorView:init(opts)
    self.VALUE_POS = 180
    self.fields = {}
	self.fieldOrder = {}

	self.btnClose = Button:New {
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
	
    self.stackPanel = StackPanel:New {
        y = 0,
        x = 0,
		right = 0,
		
		centerItems = false,
		
		-- autosize = true, -- FIXME: autosize is not working. If enabled (and height disabled) it will cause controls not to render any changes.
		-- debug = true,
		resizeItems = true, -- FIXME: This is also temporarily enabled because of the bug above
		
        itemPadding = {0,10,0,0},
        padding = {0,0,0,0},
        margin = {0,0,0,0},
        itemMargin = {5,0,0,0},
    }
	self.stackPanel:DisableRealign()
end

-- Override
function MapEditorView:OnStartChange(name, value)
end
-- Override
function MapEditorView:OnEndChange(name, value)
end
-- Override 
function MapEditorView:OnFieldChange(name, value)
end
-- Override 
function MapEditorView:IsValidTest(state)
    return false
end

-- NOTICE: Invoke :Finalize at the end of init

--
function MapEditorView:Finalize(children)
	table.insert(children, self.btnClose)
	
	self.window = Control:New {
--         parent = screen0,
--         x = 10,
--         y = 100,
--         width = 550,
--         height = 800,
		x = 0,
		y = 0,
		bottom = 0,
		right = 0,
        caption = '',
        children = children,
    }
	
	self.stackPanel:EnableRealign()
	self:_MEGA_HACK()
	
	SCEN_EDIT.view:SetMainPanel(self.window)
end

function MapEditorView:_MEGA_HACK()
	-- FIXME: Mega hack to manually resize the stackPanel since autosize is broken
	SCEN_EDIT.delay(function()
	SCEN_EDIT.delay(function()
	self.stackPanel.resizeItems = false
	local h = 0
	for _, c in pairs(self.stackPanel.children) do
		if type(c) == "table" then
			c:UpdateLayout()
			h = h + c.height + self.stackPanel.itemPadding[2]
		end
	end
	self.stackPanel:Resize(nil, h)
	end)
	end)
end

-- Don't use this directly because ordering would be messed up.
function MapEditorView:_SetFieldVisible(name, visible)
	if not self.fields[name] then
		Spring.Log("Scened", LOG.ERROR, "Trying to set visibility on an invalid field: " .. tostring(name))
		return
	end
	
	if visible == nil then
		return
	end
	
	local ctrl = self.fields[name].ctrl
	-- HACK: use Add/Remove instead of Show/Hide to have proper ordering
	--if ctrl.visible ~= visible then
	if ctrl._visible ~= visible then
		if visible then
			self.stackPanel:AddChild(ctrl)
			ctrl._visible = true
			--ctrl:Show()
		else
			self.stackPanel:RemoveChild(ctrl)
			ctrl._visible = false
			--ctrl:Hide()
		end
	end
end

function MapEditorView:SetInvisibleFields(...)
	self.stackPanel:DisableRealign()
	
	local fields = {...}
	for i = #self.fieldOrder, 1, -1 do
		local name = self.fieldOrder[i]
		self:_SetFieldVisible(name, false)
	end
	
	self.stackPanel.resizeItems = true
	
	for i = 1, #self.fieldOrder do
		local name = self.fieldOrder[i]
		if not table.ifind(fields, name) then
			self:_SetFieldVisible(name, true)
		end
	end

	self.stackPanel:EnableRealign()
	self:_MEGA_HACK()
end

function MapEditorView:AddControl(name, children)
    self.fields[name] = {
        ctrl = self:_AddControl(name, children),
        name = name,
    }
    return self.fields[name]
end

function MapEditorView:_AddControl(name, children)
	local ctrl = Control:New {
        autosize = true,
        padding = {0, 0, 0, 0},
        children = children
    }
	self.stackPanel:AddChild(ctrl)
	table.insert(self.fieldOrder, name)
	return ctrl
end

function MapEditorView:ParseKey(editBox, key, mods, ...)
    if key == Spring.GetKeyCode("enter") or 
		key == Spring.GetKeyCode("numpad_enter") then
        screen0:FocusControl(nil)
        return true
    end
end

function MapEditorView:UpdateChoiceField(name, source)
    local field = self.fields[name]
    -- HACK
    if source ~= field.comboBox then
        for i, id in pairs(field.comboBox.ids) do
            if id == field.value then
                field.comboBox:Select(i)
                break
            end
        end
    end
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    self:OnFieldChange(field.name, field.value)
    if self:IsValidTest(currentState) then
        currentState[field.name] = field.value
    end
end

function MapEditorView:SetChoiceField(name, value, source)
    local field = self.fields[name]
    if value ~= nil and value ~= field.value then
        field.value = value
        self:UpdateChoiceField(field.name, source)
    end
end

function MapEditorView:AddChoiceProperty(field)
    self.fields[field.name] = field

    field.label = Label:New {
        caption = field.title,
        x = 1,
        y = 10,
		autosize = true,
    }
	local ids, captions = field.items, field.captions
	if captions == nil then
		captions = field.items
	end
    field.comboBox = ComboBox:New {
        x = self.VALUE_POS - 5,
        y = 0,
        width = 150,
        height = 30,
        items = captions,
		ids = ids,
    }
    field.comboBox.OnSelect = {
        function(obj, indx)
            local value = field.comboBox.ids[indx]
            self:SetChoiceField(field.name, value, field.comboBox)
        end
    }
    field.value = field.items[1]

    field.Set = function(...)
        self:SetChoiceField(field.name, ...)
    end
    field.ctrl = self:_AddControl(field.name, {
		field.label,
		field.comboBox,
	})
	return field
end

function MapEditorView:UpdateBooleanField(name, source)
    local field = self.fields[name]
    if source ~= field.checkBox then
        if field.checkBox.checked ~= field.value then
            field.checkBox:Toggle()
        end
        field.checkBox:Invalidate()
    end
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    self:OnFieldChange(field.name, field.value)
    if self:IsValidTest(currentState) then
        currentState[field.name] = field.value
    end
end

function MapEditorView:SetBooleanField(name, value, source)
    local field = self.fields[name]
    if value ~= nil and value ~= field.value then
        field.value = value
        self:UpdateBooleanField(field.name, source)
    end
end

function MapEditorView:AddBooleanProperty(field)
    self.fields[field.name] = field

    field.checkBox = Checkbox:New {
		caption = field.title,
        x = 1,
        y = 0,
        width = self.VALUE_POS + 10,
        height = 20,
        checked = field.value,
    }
    field.checkBox.OnChange = {
        function(obj, checked)
            self:SetBooleanField(field.name, checked, field.checkBox)
        end
    }

    field.Set = function(...)
        self:SetBooleanField(field.name, ...)
    end
    field.ctrl = self:_AddControl(field.name, {
        field.checkBox,
    })
    return field
end

function MapEditorView:UpdateNumericField(name, source)
    local field = self.fields[name]

    -- HACK
    local v = tostring(field.value)
    v = v:sub(1, math.min(#v, 6))
    if source ~= field.editBox then
        field.editBox:SetText(v)
    end
--     if source ~= field.trackbar then
--         field.trackbar:SetValue(field.value)
--     end
    if source ~= field.lblValue then
        field.lblValue:SetCaption(v)
    end
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    self:OnFieldChange(field.name, field.value)
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
        if field.maxValue then
            value = math.min(field.maxValue, value)
        end
        if field.minValue then
            value = math.max(field.minValue, value)
        end
        field.value = value
        self:UpdateNumericField(field.name, source)
    end
    field.inUpdate = nil
end

function MapEditorView:_OnStartChange(name, value)
    if not self._startedChanging then
        self._startedChanging = true
        self:OnStartChange(name, value)
    end
end

function MapEditorView:_OnEndChange(name, value)
    if self._startedChanging then
        self._startedChanging = false
        self:OnEndChange(name, value)
    end
end

function MapEditorView:AddNumericProperty(field)
    if field.step == nil then
        field.step = 1
    end
    self.fields[field.name] = field
    local v = tostring(field.value)
    v = v:sub(1, math.min(#v, 6))

    field.editBox = EditBox:New {
        text = v,
        x = 1,
        y = 1,
        width = 200,
        height = 20,
        KeyPress = function(...)
			if not self:ParseKey(...) then
				return Chili.EditBox.KeyPress(...)
			end
			return true
		end,
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
        OnFocusUpdate = {
            function(...)
                if not field.editBox.state.focused then
                    field.button:Show()
                    field.editBox:Hide()
                    self.stackPanel:Invalidate()
                    self:_OnEndChange(name, value)
                end
            end
        },
    }
    field.lblValue = Label:New {
        caption = "",
        width = "100%",
        right = 5,
        y = 5,
--                 padding = { 0, 0, 0, 0 },
        align = "right",
    }
    field.button = Button:New {
        caption = "",
        x = 1,
        y = 1,
        width = 200,
        height = 30,
        padding = {0, 0, 0, 0,},
        OnClick = {
            function()
                if not self.notClick then
                    field.button:Hide()
                    field.editBox:Show()
                    screen0:FocusControl(field.editBox)
                    self:_OnStartChange(field.name, value)
                end
            end
        },
        OnMouseUp = {
            function()
                SCEN_EDIT.SetMouseCursor()
                self.startX = nil
                self.notClick = false
                self:_OnEndChange(field.name, value)
            end
        },
        OnMouseMove = {
            function(obj, x, y, _, _, btn, ...)
                if btn then
                    local _, _, _, shift = Spring.GetModKeyState()
                    if not self.startX then
                        self.startX = x
                        self.currentX = x
                    end
                    local dx = x - self.currentX
                    self.currentX = x
                    if math.abs(x - self.startX) > 4 then
                        self.notClick = true
                        self:_OnStartChange(field.name, value)
                    end
                    if self.notClick then
                        if shift then
                            dx = dx * 0.1
                        end
                        local value = field.value + dx * field.step
                        self:SetNumericField(field.name, value, obj)
                    end
                    SCEN_EDIT.SetMouseCursor("resize-x")
                end
            end
        },
        children = { 
            field.lblValue,
            Label:New {
                caption = field.title,
                x = 10,
                y = 5,
--                 padding = { 0, 0, 0, 0 },
                autosize = true,
                tooltip = field.tooltip,
            },
        },
    }
--     field.trackbar = Trackbar:New {
--         x = self.VALUE_POS + 130,
--         y = 1,
--         value = field.value,
--         min = field.minValue,
--         max = field.maxValue,
--         step = field.step or 0.01,
--         width = 95,
--         height = 20,
--     }
--     field.trackbar.OnChange = {
--         function(obj, value)
--             self:SetNumericField(field.name, value, obj)
--         end
--     }
--     field.trackbar.OnMouseUp = {
--         function(obj, value)
--             if self._startedChanging then
--                 self._startedChanging = false
--                 self:OnEndChange(field.name, value)
--             end
--         end
--     }
--     field.trackbar.OnMouseDown = {
--         function(obj, value)
--             if not self._startedChanging then
--                 self._startedChanging = true
--                 self:OnStartChange(field.name, value)
--             end
--         end
--     }

    field.Set = function(...)
        self:SetNumericField(field.name, ...)
    end
    field.ctrl = self:_AddControl(field.name, {
-- 		field.label,
 		field.editBox,
-- 		field.trackbar,
        field.button,
	})
    field.editBox:Hide()
	return field
end

function MapEditorView:UpdateStringField(name, source)
    local field = self.fields[name]

    -- HACK
    if source ~= field.editBox then
        field.editBox:SetText(field.value)
    end
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    self:OnFieldChange(field.name, field.value)
    if self:IsValidTest(currentState) then
        currentState[field.name] = field.value
    end
end

function MapEditorView:SetStringField(name, value, source)
    local field = self.fields[name]
    if field.inUpdate then
        return
    end

    field.inUpdate = true
    if value ~= field.value then
        field.value = value
        self:UpdateStringField(field.name, source)
    end
    field.inUpdate = nil
end

function MapEditorView:AddStringProperty(field)
    self.fields[field.name] = field

    field.label = Label:New {
        caption = field.title,
        x = 1,
        y = 1,
        autosize = true,
        tooltip = field.tooltip,
    }
    field.editBox = EditBox:New {
        text = field.value,
        x = self.VALUE_POS,
        y = 1,
        width = 100,
        height = 20,
        KeyPress = function(...)
			if not self:ParseKey(...) then
				return Chili.EditBox.KeyPress(...)
			end
			return true
		end,
        OnTextInput = {
            function() 
                self:SetStringField(field.name, field.editBox.text, field.editBox)
            end
        },
        OnKeyPress = {
            function() 
                self:SetStringField(field.name, field.editBox.text, field.editBox)
            end
        },
        OnFocusUpdate = {
            function(...)
                if not field.editBox.state.focused then
                    self:_OnEndChange(name, value)
                else
                    self:_OnStartChange(name, value)
                end
            end
        },
    }

    field.Set = function(...)
        self:SetStringField(field.name, ...)
    end
    field.ctrl = self:_AddControl(field.name, {
        field.label,
        field.editBox,
    })
    return field
end

function MapEditorView:UpdateColorbarsField(name, source)
    local field = self.fields[name]

    if source ~= field.colorbars then
        field.colorbars:SetColor(field.value)
    end
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    self:OnFieldChange(field.name, field.value)
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
        x = self.VALUE_POS,
        y = 1,
        width = 225,
        height = 60,
        OnChange = {
            function(obj, value)
                self:SetColorbarsField(field.name, value, obj)
            end
        },
    }
    field.Set = function(...)
        self:SetColorbarsField(field.name, ...)
    end
    field.ctrl = self:_AddControl(field.name, {
		field.label,
		field.colorbars,
	})
	return field
end