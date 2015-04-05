TerrainIncreaseState = AbstractHeightmapEditingState:extends{}

function TerrainIncreaseState:Apply(x, z, strength)
    if self:super("Apply", x, z, strength) then
        local cmd = TerrainIncreaseCommand(x, z, self.size, strength, self.rotation)
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
        gl.Color(1, 1, 1, 0.4)
        gl.Utilities.DrawGroundCircle(x, z, self.size)
        gl.Color(0, 0, 1, 0.4)
        gl.Utilities.DrawGroundCircle(x, z, self.size * 0.95)
        gl.PopMatrix()
    end
end
