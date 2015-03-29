AbstractHeightmapEditingState = AbstractEditingState:extends{}

function AbstractHeightmapEditingState:init(toDecrease)
end

function AbstractHeightmapEditingState:enterState()
    self.size = math.min(self.maxSize, self.size)
    self.size = math.max(self.minSize, self.size)
end

function AbstractHeightmapEditingState:KeyPress(key, mods, isRepeat, label, unicode)
    if self.startedChanging then
        return false
    end
    -- FIXME: cannot use "super" here in the current version of LCS and the new version is broken
    if AbstractEditingState.KeyPress(self, key, mods, isRepeat, label, unicode) then
        return true
    end
    if key == 27 then --KEYSYMS.ESC then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    elseif key == 49 then -- 1
        local newState = TerrainIncreaseState()
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 50 then -- 2
        local newState = TerrainSmoothState()
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 51 then -- 3
        local newState = TerrainLevelState()
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 52 then -- 4
        local newState = TerrainChangeHeightRectState()
        SCEN_EDIT.stateManager:SetState(newState)
    else
        return false
    end
    return true
end

function AbstractHeightmapEditingState:AlterTerrain(x, z, amount)
    local now = os.clock()
    if not self.lastTime or now - self.lastTime >= 0.01 then
        self.lastTime = now
        return true
    end
end

function AbstractHeightmapEditingState:MousePress(x, y, button)
    local _, _, _, shift = Spring.GetModKeyState()
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            local amount = self.strength
            if shift then
                amount = -amount
            end
            self:startChanging()
            self:AlterTerrain(coords[1], coords[3], amount)
        end
        return true
    end
    if button == 3 then
        self:stopChanging()
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function AbstractHeightmapEditingState:MouseRelease(x, y, button)
    if button == 1 then
        self:stopChanging()
    end
end

function AbstractHeightmapEditingState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    return true
end

function AbstractHeightmapEditingState:MouseWheel(up, value)
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

function AbstractHeightmapEditingState:GameFrame(frameNum)
    local x, y, button1, _, button3 = Spring.GetMouseState()
    local _, _, _, shift = Spring.GetModKeyState()
    if button1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            local amount = self.strength
            if shift then
                amount = -amount
            end
            self:AlterTerrain(coords[1], coords[3], amount)
        end
    end
end

function AbstractHeightmapEditingState:startChanging()
    if not self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(true)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = true
    end
end

function AbstractHeightmapEditingState:stopChanging()
    if self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(false)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = false
    end
end