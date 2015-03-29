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

function AbstractMapEditingState:Apply(x, z, amount)
    local now = os.clock()
    if not self.lastTime or now - self.lastTime >= 0.01 then
        self.lastTime = now
        return true
    end
end

function AbstractMapEditingState:MousePress(x, y, button)
    local _, _, _, shift = Spring.GetModKeyState()
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            local amount = self.strength
            if shift then
                amount = -amount
            end
            self:startChanging()
            self:Apply(coords[1], coords[3], amount)
            return true
        end
    end
    if button == 3 then
        self:stopChanging()
        SCEN_EDIT.stateManager:SetState(DefaultState())
        return true
    end
end

function AbstractMapEditingState:MouseRelease(x, y, button)
    if button == 1 then
        self:stopChanging()
    end
end

function AbstractMapEditingState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    return true
end

function AbstractMapEditingState:MouseWheel(up, value)
    local _, ctrl = Spring.GetModKeyState()
    if ctrl then
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
    if button1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            local amount = self.strength
            if shift then
                amount = -amount
            end
            self:Apply(coords[1], coords[3], amount)
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