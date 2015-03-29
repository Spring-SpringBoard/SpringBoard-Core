TerrainLevelState = AbstractHeightmapEditingState:extends{}

function TerrainLevelState:Apply(x, z)
    if self:super("Apply", x, z) then
        local cmd = TerrainLevelCommand(x, z, self.size, self.height)
        SCEN_EDIT.commandManager:execute(cmd)
        return true
    end
end

function TerrainLevelState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        gl.Color(1, 1, 1, 0.4)
        gl.Utilities.DrawGroundCircle(x, z, self.size)
        gl.Color(1, 0, 0, 0.4)
        gl.Utilities.DrawGroundCircle(x, z, self.size * 0.95)
        gl.PopMatrix()
    end
end

function TerrainLevelState:MousePress(x, y, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground"  then
        self.height = coords[2]
    end
    return self:super("MousePress", x, y, button)
end