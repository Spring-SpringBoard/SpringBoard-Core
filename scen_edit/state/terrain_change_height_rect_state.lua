TerrainChangeHeightRectState = AbstractHeightmapEditingState:extends{}

function TerrainChangeHeightRectState:init(toDecrease)
    self.size = 100
    self.strength = 5
    self.toDecrease = toDecrease
    self.startedChanging = false
    self.minSize = 20
    self.maxSize = 1000
end

function TerrainChangeHeightRectState:Apply(x, z, amount)
    if self:super("Apply", x, z, amount) then
        local x1, z1= x - self.size / 2, z - self.size / 2
        local x2, z2 = x + self.size / 2, z + self.size / 2
        local cmd = TerrainChangeHeightRectCommand(x1, z1, x2, z2, amount)
        SCEN_EDIT.commandManager:execute(cmd)
        return true
    end
end

function TerrainChangeHeightRectState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        gl.Color(1, 1, 1, 0.4)
        gl.Utilities.DrawGroundRectangle(x - self.size/2, z - self.size/2, x + self.size/2, z + self.size/2)
        gl.Color(0, 0, 1, 0.4)
        gl.Utilities.DrawGroundRectangle(x - self.size/2 * 0.95, z - self.size/2 * 0.95, x + self.size/2 * 0.95, z + self.size/2 * 0.95)
        gl.PopMatrix()
    end
end
