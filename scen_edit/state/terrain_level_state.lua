TerrainLevelState = AbstractHeightmapEditingState:extends{}

function TerrainLevelState:init()
    self.size = 100
    self.strength = 1
    self.startedChanging = false
end

function TerrainLevelState:AlterTerrain(x, z)
    local currentFrame = Spring.GetGameFrame()
    if not self.lastChangeFrame or currentFrame - self.lastChangeFrame >= 0 then
        self.lastChangeFrame = currentFrame
        local cmd = TerrainLevelCommand(x, z, self.size, self.height)
        SCEN_EDIT.commandManager:execute(cmd)
        return true
    end
end

function TerrainLevelState:startChanging()
    if not self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(true)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = true
    end
end

function TerrainLevelState:stopChanging()
    if self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(false)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = false
    end
end

function TerrainLevelState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            self.height = coords[2]
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

function TerrainLevelState:MouseRelease(x, y, button)
    if button == 1 then
        self:stopChanging()
    end
end

function TerrainLevelState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    return true
end

function TerrainLevelState:MouseWheel(up, value)
    local _, ctrl = Spring.GetModKeyState()
    if ctrl then
        if up then
            self.size = self.size + self.size * 0.2 + 2
        else
            self.size = self.size - self.size * 0.2 - 2
        end
        self.size = math.min(10000, self.size)
        self.size = math.max(20, self.size)
        return true
    end
end

function TerrainLevelState:GameFrame(frameNum)
    local x, y, button1, _, button3 = Spring.GetMouseState()
    if button1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            self:AlterTerrain(coords[1], coords[3])
        end
    end
end

function TerrainLevelState:DrawWorld()
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
