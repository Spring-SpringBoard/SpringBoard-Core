TerrainSmoothState = AbstractEditingState:extends{}

function TerrainSmoothState:init()
    self.size = 100
    self.strength = 1
    self.startedChanging = false
end

function TerrainSmoothState:AlterTerrain(x, z, amount)
    local currentFrame = Spring.GetGameFrame()
    if not self.lastChangeFrame or currentFrame - self.lastChangeFrame >= 0 then
        self.lastChangeFrame = currentFrame
        local cmd = TerrainSmoothCommand(x, z, self.size, amount)
        SCEN_EDIT.commandManager:execute(cmd)
        return true
    end
end

function TerrainSmoothState:startChanging()
    if not self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(true)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = true
    end
end

function TerrainSmoothState:stopChanging()
    if self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(false)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = false
    end
end

function TerrainSmoothState:MousePress(x, y, button)
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

function TerrainSmoothState:MouseRelease(x, y, button)
    if button == 1 then
        self:stopChanging()
    end
end

function TerrainSmoothState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    return true
end

function TerrainSmoothState:MouseWheel(up, value)
    local _, ctrl = Spring.GetModKeyState()
    if ctrl then
        if up then
            self.size = self.size + self.size * 0.2 + 2
        else
            self.size = self.size - self.size * 0.2 - 2
        end
        self.size = math.min(1000, self.size)
        self.size = math.max(20, self.size)
        return true
    end
end

function TerrainSmoothState:GameFrame(frameNum)
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

function TerrainSmoothState:KeyPress(key, mods, isRepeat, label, unicode)
    if self.startedChanging then
        return
    end
    if self:super("KeyPress", key, mods, isRepeat, label, unicode) then
        return true
    end
    if key == 27 then --KEYSYMS.ESC then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    elseif key == 49 then -- 1
        local newState = TerrainIncreaseState()
        newState.size = self.size
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 50 then -- 2
        local newState = TerrainChangeHeightRectState()
        --newState.size = self.size
        SCEN_EDIT.stateManager:SetState(newState)
    end
end

function TerrainSmoothState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        currentState = SCEN_EDIT.stateManager:GetCurrentState()
        gl.Color(1, 1, 1, 0.4)
        gl.Utilities.DrawGroundCircle(x, z, self.size)
        gl.Color(0, 0, 1, 0.4)
        gl.Utilities.DrawGroundCircle(x, z, self.size * 0.95)
        gl.PopMatrix()
    end
end
