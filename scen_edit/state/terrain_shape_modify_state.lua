TerrainShapeModifyState = AbstractHeightmapEditingState:extends{}

function TerrainShapeModifyState:init(editorView)
    self:super("init", editorView)
    self.paintTexture = self.editorView.paintTexture
end

function TerrainShapeModifyState:Apply(x, z, strength)
    if self:super("Apply", x, z, strength) then
        if SCEN_EDIT.model.terrainManager:getShape(self.paintTexture) == nil then
            SCEN_EDIT.model.terrainManager:generateShape(self.paintTexture)
        end

        local cmd = TerrainShapeModifyCommand(x, z, self.size, strength, self.paintTexture, self.rotation)
        SCEN_EDIT.commandManager:execute(cmd)
        return true
    end
end

function TerrainShapeModifyState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        gl.Color(1, 1, 1, 0.4)
        gl.Utilities.DrawGroundRectangle(x - self.size, z - self.size, x + self.size, z + self.size)
        gl.Color(0, 0, 1, 0.4)
        gl.Utilities.DrawGroundRectangle(x - self.size * 0.95, z - self.size * 0.95, x + self.size * 0.95, z + self.size * 0.95)
        gl.PopMatrix()
    end
end
