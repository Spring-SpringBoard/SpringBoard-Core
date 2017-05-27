SB.Include(SB_VIEW_FIELDS_DIR .. "string_field.lua")

NumericField = StringField:extends{}
function NumericField:Update(source)
    local v = string.format(self.format, self.value)
    if source ~= self.editBox and not self.editBox.state.focused then
        self.editBox:SetText(v)
    end
    if source ~= self.lblValue then
        self.lblValue:SetCaption(v)
    end
end

function NumericField:Validate(value)
    local valid, value = self:super("Validate", tonumber(value))
    if value then
        if self.maxValue then
            value = math.min(self.maxValue, value)
        end
        if self.minValue then
            value = math.max(self.minValue, value)
        end
        return true, value
    end
    return nil
end

function NumericField:init(field)
    self.decimals = 2
    self.value = 0

    StringField.init(self, field)
    self.format = "%." .. tostring(self.decimals) .. "f"
    if self.step == nil then
        self.step = 1
        if self.minValue and self.maxValue then
            self.step = (self.maxValue - self.minValue) / 200
        end
    end
    local v = string.format(self.format, self.value)

    self.lblValue:SetCaption(v)
    self.editBox:SetText(v)
    self.button.OnMouseUp = {
        function(...)
            if not self.notClick then
                return
            end
            SB.SetMouseCursor()
            self.lblValue.font:SetColor(1, 1, 1, 1)
            self.lblTitle.font:SetColor(1, 1, 1, 1)
            self.lblTitle:Invalidate()
            if self.startX and self.startY then
                Spring.WarpMouse(self.startX, self.startY)
            end
            self.startX = nil
            self.notClick = false
            self.ev:_OnEndChange(self.name)
        end
    }
    self.button.OnMouseMove = {
        function(obj, x, y, dx, dy, btn, ...)
            if btn == 1 then
                local vsx, vsy = Spring.GetViewGeometry()
                x, y = Spring.GetMouseState()
                local _, _, _, shift = Spring.GetModKeyState()
                if not self.startX then
                    self.startX = x
                    self.startY = y
                    self.currentX = x
                    self.lblValue.font:SetColor(0.96,0.83,0.09, 1)
                    self.lblTitle.font:SetColor(0.96,0.83,0.09, 1)
                    self.lblTitle:Invalidate()
                end
                self.currentX = x
                if math.abs(x - self.startX) > 4 then
                    self.notClick = true
                    self.ev:_OnStartChange(self.name)
                end
                if self.notClick then
                    if shift then
                        dx = dx * 0.1
                    end
                    local value = self.value + dx * self.step
                    self:Set(value, obj)
                end
                -- FIXME: This -could- be Spring.WarpMouse(self.startX, self.startY) but it doesn't seem to work well
                Spring.WarpMouse(vsx/2, vsy/2)
                SB.SetMouseCursor("empty")
            end
        end
    }
end
