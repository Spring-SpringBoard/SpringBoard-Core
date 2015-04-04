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
    if not self.lastTime then
        self.lastTime = now
        return true
    end
    local delay = math.max(self.applyDelay or 0, self._initialDelay or 0)
    if delay ~= 0 then
        if now - self.lastTime >= delay then
            self.lastTime = now
            self._initialDelay = 0
            return true
        else
            return false
        end
    end
    return true
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
            self.x, self.z = coords[1], coords[3]
            self:Apply(self.x, self.z, strength)
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
    if result == "ground"  then
        local strength = self.strength
        if button == 3 and strength ~= nil then
            strength = -strength
        end
        self.x, self.z = coords[1], coords[3]
        self:Apply(self.x, self.z, strength)
    end
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
    if self.updateDelay then
        local now = os.clock()
        if not self.lastUpdateTime or now - self.lastUpdateTime >= self.updateDelay then
            self.lastUpdateTime = now
        else
            return false
        end
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
            local x, z = coords[1], coords[3]
            local tolerance = 200
            if math.abs(x - self.x) > tolerance or math.abs(z - self.z) > tolerance then
                self.x, self.z = x, z
            end
            self:Apply(self.x, self.z, strength)
        end
    end
end

function AbstractMapEditingState:startChanging()
    if not self.startedChanging then
        self._initialDelay = self.initialDelay
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
        self.lastTime = nil
    end
end