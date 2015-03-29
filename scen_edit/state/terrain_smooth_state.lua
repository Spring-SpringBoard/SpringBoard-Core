TerrainSmoothState = AbstractHeightmapEditingState:extends{}

function TerrainSmoothState:init(heightmapEditorView)
    self:super("init", heightmapEditorView)
    self.sigma = 1
--     self.minSize = 20
--     self.maxSize = 200
end

function TerrainSmoothState:Apply(x, z)
    if self:super("Apply", x, z, amount) then
        self.sigma = math.max(math.min(self.size / self.maxSize, 1.5), 0.35)
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
        gl.Color(1, 1, 1, 0.4)
        gl.Utilities.DrawGroundCircle(x, z, self.size)
        gl.Color(0, 1, 0, 0.4)
        gl.Utilities.DrawGroundCircle(x, z, self.size * 0.95)
        gl.PopMatrix()
    end
end
