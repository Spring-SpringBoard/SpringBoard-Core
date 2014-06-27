TerrainChangeHeightRectState = AbstractEditingState:extends{}

function TerrainChangeHeightRectState:init(toDecrease)
    self.size = 100
    self.strength = 5
    self.toDecrease = toDecrease
    self.startedChanging = false
end

function TerrainChangeHeightRectState:AlterTerrain(x1, z1, x2, z2, amount)
    local currentFrame = Spring.GetGameFrame()
    if not self.lastChangeFrame or currentFrame - self.lastChangeFrame >= 0 then
        self.lastChangeFrame = currentFrame
        local cmd = TerrainChangeHeightRectCommand(x1, z1, x2, z2, amount)
        SCEN_EDIT.commandManager:execute(cmd)
        return true
    end
end

function TerrainChangeHeightRectState:startChanging()
    if not self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(true)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = true
    end
end

function TerrainChangeHeightRectState:stopChanging()
    if self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(false)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = false
    end
end

function TerrainChangeHeightRectState:MousePress(x, y, button)
    local _, _, _, shift = Spring.GetModKeyState()
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            local amount = self.strength
            if shift then
                amount = -amount                
            end
            self:startChanging()
            self:AlterTerrain(coords[1] - self.size/2, coords[3] - self.size/2, coords[1] + self.size/2, coords[3] + self.size/2, amount)
        end
        return true
    end
    if button == 3 then
        self:stopChanging()
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function TerrainChangeHeightRectState:MouseRelease(x, y, button)
    if button == 1 then
        self:stopChanging()
    end
end

function TerrainChangeHeightRectState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    return true
end

function TerrainChangeHeightRectState:MouseWheel(up, value)
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

function TerrainChangeHeightRectState:GameFrame(frameNum)
    local x, y, button1, _, button3 = Spring.GetMouseState()
    local _, _, _, shift = Spring.GetModKeyState()
    if button1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            local amount = self.strength
            if shift then
                amount = -amount
            end
            self:AlterTerrain(coords[1] - self.size/2, coords[3] - self.size/2, coords[1] + self.size/2, coords[3] + self.size/2, amount)
        end
    end
end

function TerrainChangeHeightRectState:KeyPress(key, mods, isRepeat, label, unicode)
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
        --newState.size = self.size
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 51 then -- 3
        local newState = TerrainSmoothState()
        --newState.size = self.size
        SCEN_EDIT.stateManager:SetState(newState)
    end
end

function TerrainChangeHeightRectState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        currentState = SCEN_EDIT.stateManager:GetCurrentState()
        gl.Color(1, 1, 1, 0.4)
        gl.Utilities.DrawGroundRectangle(x - self.size/2, z - self.size/2, x + self.size/2, z + self.size/2)
        gl.Color(0, 0, 1, 0.4)
        gl.Utilities.DrawGroundRectangle(x - self.size/2 * 0.95, z - self.size/2 * 0.95, x + self.size/2 * 0.95, z + self.size/2 * 0.95)
        gl.PopMatrix()
    end
end
