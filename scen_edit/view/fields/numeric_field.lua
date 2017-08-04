SB.Include(SB_VIEW_FIELDS_DIR .. "string_field.lua")

NumericField = StringField:extends{}
function NumericField:Update(source)
    local v = self:__GetDisplayText()
    if source ~= self.editBox and not self.editBox.state.focused then
        self.editBox:SetText(v)
    end
    if source ~= self.lblValue then
        self.lblValue:SetCaption(v)
    end
    if self.minValue and self.maxValue then
        self.button.__progress = (self.value - self.minValue) / (self.maxValue - self.minValue)
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
    self.__dragSensitivity = 3
    self.__shiftMultiplier = 0.1

    self:__SetDefault("decimals", 2)
    self:__SetDefault("value", 0)
    self:__SetDefault("allowNil", false)
    self:__SetDefault("__btnClassname", "progress_button")

    StringField.init(self, field)

    self.format = "%." .. tostring(self.decimals) .. "f"
    if self.step == nil then
        self.step = 1
        if self.minValue and self.maxValue then
            self.step = (self.maxValue - self.minValue) / 200
        end
    end

    local v = self:__GetDisplayText()
    self.lblValue:SetCaption(v)
    self.editBox:SetText(v)

    self.button.OnMouseUp = {
        function(...)
            if self.__isDragging then
                self:__StopDragging()
            end
        end
    }
    self.button.OnMouseMove = {
        function(obj, _, _, dx, _, btn, ...)
            if btn ~= 1 then
                return
            end

            -- Save the initial state so it can be reverted back to
            local x, y = Spring.GetMouseState()
            if not self.__initX then
                self.__initX = x
                self.__initY = y
            end
            -- Determine whether we are dragging the mouse
            if not self.__isDragging and
                math.abs(x - self.__initX) > self.__dragSensitivity then
                -- Initialize the dragging state
                self:__StartDragging()
            end
            -- Update dragging
            if self.__isDragging then
                self:__UpdateDragging(dx)
            end
        end
    }
end

-- Overriden
function NumericField:__GetDisplayText()
    return string.format(self.format, self.value)
end

-- Overriden
function NumericField:__OnClick()
    if not self.__isDragging then
        StringField.__OnClick(self)
    end
end

function NumericField:__StartDragging()
    -- Set the internal state
    self.__isDragging = true

    -- Set the controls
    self.lblValue.font:SetColor(0.96,0.83,0.09, 1)
    self.lblTitle.font:SetColor(0.96,0.83,0.09, 1)
    self.lblTitle:Invalidate()

    -- Hide the mouse cursor
    SB.SetMouseCursor("empty")

    -- Notify editor that we have started dragging
    self.ev:_OnStartChange(self.name)

    -- Setup the rendering control
    self:__SetupDraggingControl()
end

function NumericField:__StopDragging()
    -- Reset the controls
    self.lblValue.font:SetColor(1, 1, 1, 1)
    self.lblTitle.font:SetColor(1, 1, 1, 1)
    self.lblTitle:Invalidate()

    -- Hide the rendering control
    self:__HideDraggingControl()

    -- Reset the mouse cursor and position
    SB.SetMouseCursor()
    if self.__initX and self.__initY then
        Spring.WarpMouse(self.__initX, self.__initY)
    end

    -- Reset the internal state
    self.__initX, self.__initY = nil, nil
    self.__isDragging = false

    -- Notify editor that we have stopped dragging
    self.ev:_OnEndChange(self.name)
end

function NumericField:__UpdateDragging(delta)
    -- Apply the shift multiplier if it's pressed
    local _, _, _, shift = Spring.GetModKeyState()
    if shift then
        delta = delta * self.__shiftMultiplier
    end
    -- Set the new value
    local value = self.value + delta * self.step
    self:Set(value, self.button)

    if self.value == self.minValue or self.value == self.maxValue then
        if not self.__reachedExtreme  then
            self.lblValue.font:SetColor(0, 1.0, 0.1, 1)
            self.lblTitle.font:SetColor(0, 1.0, 0.1, 1)
            self.lblTitle:Invalidate()
            self.__reachedExtreme = true
        end
    elseif self.__reachedExtreme then
        self.lblValue.font:SetColor(0.96,0.83,0.09, 1)
        self.lblTitle.font:SetColor(0.96,0.83,0.09, 1)
        self.lblTitle:Invalidate()
        self.__reachedExtreme = false
    end

    -- Make the mouse fixed
    Spring.WarpMouse(self.__initX, self.__initY)
end

function NumericField:__DrawDisplayControl()
    -- Leave if we're no longer dragging
    if not self.__isDragging then
        return
    end

    local x, y = self.button:CorrectlyImplementedLocalToScreen(self.button.x, 0)
    local w = self.button.width

    local offy = -10
    if self.minValue then
        self.__draggingFont:Draw(self.__minValueStr,
            self.__leftStart, y - offy)
    end
    if self.maxValue then
        self.__draggingFont:Draw(self.__maxValueStr,
            x + w + self.__pdx + self.__ew / 2, y - offy)
    end

    return true
end

local leftDisplay = Image:New {
    file = Path.Join(SB_IMG_DIR, "left-numeric.png"),
    parent = screen0,
    keepAspect = false,
}
local rightDisplay = Image:New {
    file = Path.Join(SB_IMG_DIR, "right-numeric.png"),
    parent = screen0,
    keepAspect = false,
}
leftDisplay:Hide()
rightDisplay:Hide()
function NumericField:__SetupDraggingControl()
    if not self.__draggingFont then
        local _draggingColor = {0.76,0.63,0.06, 1}
        self.__draggingFont = Chili.Font:New {
            size = 12,
            color = _draggingColor,
            shadow = true,
        }
    end

    local x, y = self.button:CorrectlyImplementedLocalToScreen(self.button.x, 0)
    local eh = 10
    self.__ew = 10
    self.__pdx = 2

    if self.minValue then
        self.__minValueStr = string.format(self.format, self.minValue)
        local w = self.__draggingFont:GetTextWidth(tostring(self.__minValueStr))
        w = math.max(w, self.height - self.__ew)
        self.__leftStart = x - w - self.__ew / 2 - self.__pdx
        w = w + self.__ew

        leftDisplay:Show()
        leftDisplay:SetPos(x - w - self.__pdx, y - eh / 2 + 2,
                           w, self.height + eh / 2)
        leftDisplay:SetLayer(1)
    end
    if self.maxValue then
        self.__maxValueStr = string.format(self.format, self.maxValue)
        local w = self.__draggingFont:GetTextWidth(tostring(self.__maxValueStr))
        w = math.max(w, self.height - self.__ew)
        w = w + self.__ew

        rightDisplay:Show()
        rightDisplay:SetPos(x + self.button.width + self.__pdx, y - eh / 2 + 2,
                            w, self.height + eh / 2)
        rightDisplay:SetLayer(2)
    end
    SB.SetGlobalRenderingFunction(function(...)
        self:__DrawDisplayControl(...)
    end)
end

function NumericField:__HideDraggingControl()
    if leftDisplay.visible then
        leftDisplay:Hide()
    end
    if rightDisplay.visible then
        rightDisplay:Hide()
    end
    SB.SetGlobalRenderingFunction(nil)
end
