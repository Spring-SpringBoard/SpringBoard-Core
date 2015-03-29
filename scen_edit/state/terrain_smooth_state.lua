TerrainSmoothState = AbstractHeightmapEditingState:extends{}

function TerrainSmoothState:init()
    self.size = 100
    self.sigma = 1
    self.startedChanging = false
    self.minSize = 20
    self.maxSize = 200
end

function TerrainSmoothState:AlterTerrain(x, z)
    if self:super("AlterTerrain", x, z, amount) then
        self.sigma = math.max(math.min(self.size / 200, 1.5), 0.35)
        local cmd = TerrainSmoothCommand(x, z, self.size, self.sigma)
        SCEN_EDIT.commandManager:execute(cmd)
        return true
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
