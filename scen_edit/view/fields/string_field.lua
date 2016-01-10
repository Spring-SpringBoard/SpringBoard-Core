SCEN_EDIT.Include(SCEN_EDIT_VIEW_FIELDS_DIR .. "field.lua")

function ParseKey(field, editBox, key, mods, ...)
    if key == Spring.GetKeyCode("esc") then
        field:Set(field.originalValue)
        screen0:FocusControl(nil)
        return true
    end
    if key == Spring.GetKeyCode("enter") or
        key == Spring.GetKeyCode("numpad_enter") then
        screen0:FocusControl(nil)
        return true
    end
end

StringField = Field:extends{}

function StringField:Added()
    self.editBox:Hide()
end

function StringField:Update(source)
    if source ~= self.editBox then
        self.editBox:SetText(self.value)
    end
    if source ~= self.lblValue then
        self.lblValue:SetCaption(self.value)
    end
end

function StringField:init(field)
    self.width = 200
    Field.init(self, field)

    self.editBox = EditBox:New {
        text = self.value,
        width = self.width,
        height = self.height,
        KeyPress = function(...)
            if not ParseKey(self, ...) then
                return Chili.EditBox.KeyPress(...)
            end
            return true
        end,
        OnTextInput = {
            function()
                self:Set(self.editBox.text, self.editBox)
            end
        },
        OnKeyPress = {
            function()
                self:Set(self.editBox.text, self.editBox)
            end
        },
        OnFocusUpdate = {
            function(...)
                if not self.editBox.state.focused then
                    self.button:Show()
                    self.editBox:Hide()
                    self.ev.stackPanel:Invalidate()
                    self.ev:_OnEndChange(self.name)
                end
            end
        },
    }
    self.lblValue = Label:New {
        caption = self.value,
        width = "100%",
        right = 5,
        y = 5,
        align = "right",
    }
    self.lblTitle = Label:New {
        caption = self.title,
        x = 10,
        y = 5,
        autosize = true,
    }

    self.button = Button:New {
        caption = "",
        width = self.width,
        height = self.height,
        padding = {0, 0, 0, 0,},
        tooltip = self.tooltip,
        MouseDown = function(obj, x, y, btn, ...) -- Overrides Chili.Button.MouseDown
            if btn == 1 then
                return Chili.Button.MouseDown(obj, x, y, btn, ...)
            end
        end,
        OnClick = {
            function(...)
                if not self.notClick then
                    self.originalValue = self.value
                    self.button:Hide()
                    self.editBox:SetText(self.lblValue.caption)
                    self.editBox:Show()
                    self.editBox.cursor = #self.editBox.text + 1
                    self.editBox:Select(1, #self.editBox.text + 1)
                    screen0:FocusControl(self.editBox)
                    self.ev:_OnStartChange(self.name)
                end
            end
        },
        children = { 
            self.lblValue,
            self.lblTitle,
        },
    }

    self.components = {
        self.button,
        self.editBox,
    }
end