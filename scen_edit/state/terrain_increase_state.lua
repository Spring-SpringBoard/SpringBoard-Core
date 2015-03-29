TerrainIncreaseState = AbstractHeightmapEditingState:extends{}

function TerrainIncreaseState:init(toDecrease)
    self.size = 100
    self.strength = 1
    self.toDecrease = toDecrease
    self.startedChanging = false
    self.minSize = 20
    self.maxSize = 1000
end

function TerrainIncreaseState:AlterTerrain(x, z, amount)
    if self:super("AlterTerrain", x, z, amount) then
        local cmd = TerrainIncreaseCommand(x, z, self.size, amount)
        SCEN_EDIT.commandManager:execute(cmd)
        return true
    end
end

function TerrainIncreaseState:DrawWorld()
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
