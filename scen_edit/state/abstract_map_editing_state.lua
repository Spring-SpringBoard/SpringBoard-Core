AbstractMapEditingState = AbstractEditingState:extends{}

function AbstractMapEditingState:KeyPress(key, mods, isRepeat, label, unicode)
    -- disable keybindings while changing stuff
    if self.startedChanging then
        return false
    end
    -- FIXME: cannot use "super" here in the current version of LCS and the new version is broken
    if AbstractEditingState.KeyPress(self, key, mods, isRepeat, label, unicode) then
        return true
    end
    if key == 27 then -- KEYSYMS.ESC
        SCEN_EDIT.stateManager:SetState(DefaultState())
    else
        return false
    end
    return true
end

function AbstractMapEditingState:Apply(x, z, strength)
    local now = os.clock()
    if not self.lastTime or now - self.lastTime >= 0.01 then
        self.lastTime = now
        return true
    end
end

function AbstractMapEditingState:MousePress(x, y, button)
    if button == 1 or button == 3 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            local strength = self.strength
            if button == 3 and strength ~= nil then
                strength = -strength
            end
            self:startChanging()
            self:Apply(coords[1], coords[3], strength)
            return true
        end
    end
end

function AbstractMapEditingState:MouseRelease(x, y, button)
    if button == 1 or button == 3 then
        self:stopChanging()
    end
end

function AbstractMapEditingState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    return true
end

function AbstractMapEditingState:MouseWheel(up, value)
    local _, _, _, shift = Spring.GetModKeyState()
    if shift then
        if up then
            self.size = self.size + self.size * 0.2 + 2
        else
            self.size = self.size - self.size * 0.2 - 2
        end
        self.size = math.min(self.maxSize, self.size)
        self.size = math.max(self.minSize, self.size)
        return true
    end
end

function AbstractMapEditingState:Update()
    if not self.startedChanging then
        return
    end
    local x, y, button1, _, button3 = Spring.GetMouseState()
    local _, _, _, shift = Spring.GetModKeyState()
    if button1 or button3 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            local strength = self.strength
            if button3 and strength ~= nil then
                strength = -strength
            end
            self:Apply(coords[1], coords[3], strength)
        end
    end
end

function AbstractMapEditingState:startChanging()
    if not self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(true)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = true
    end
end

function AbstractMapEditingState:stopChanging()
    if self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(false)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = false
    end
end