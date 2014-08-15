TerrainSmoothState = AbstractHeightmapEditingState:extends{}

function TerrainSmoothState:init()
    self.size = 100
    self.sigma = 1
    self.startedChanging = false
end

function TerrainSmoothState:AlterTerrain(x, z)
    local currentFrame = Spring.GetGameFrame()
    self.sigma = math.max(math.min(self.size / 200, 1.5), 0.35)
    if not self.lastChangeFrame or currentFrame - self.lastChangeFrame >= 0 then
        self.lastChangeFrame = currentFrame
        local cmd = TerrainSmoothCommand(x, z, self.size, self.sigma)
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
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            self:startChanging()
            self:AlterTerrain(coords[1], coords[3])
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
        self.size = math.min(200, self.size)
        self.size = math.max(20, self.size)
        return true
    end
end

function TerrainSmoothState:GameFrame(frameNum)
    local x, y, button1, _, button3 = Spring.GetMouseState()
    if button1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            self:AlterTerrain(coords[1], coords[3])
        end
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
