TerrainSetState = AbstractHeightmapEditingState:extends{}

function TerrainSetState:Apply(x, z, strength)
    local cmd = TerrainLevelCommand(x, z, self.size, strength)
    SCEN_EDIT.commandManager:execute(cmd)
    return true
end

function TerrainSetState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        gl.Color(1, 1, 1, 0.4)
        gl.Utilities.DrawGroundCircle(x, z, self.size)
        gl.Color(0, 0.5, 0.5, 0.4)
        gl.Utilities.DrawGroundCircle(x, z, self.size * 0.95)
        gl.PopMatrix()
    end
end