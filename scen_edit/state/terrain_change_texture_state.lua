TerrainChangeTextureState = AbstractMapEditingState:extends{}
SCEN_EDIT.Include("scen_edit/model/texture_manager.lua")

function TerrainChangeTextureState:init(editorView)
    AbstractMapEditingState.init(self, editorView)
    self.paintTexture   = self.editorView.paintTexture
    self.penTexture     = self.editorView.penTexture
    self.texScale       = self.editorView.fields["texScale"].value
    self.detailTexScale = self.editorView.fields["detailTexScale"].value
    self.mode           = self.editorView.fields["mode"].value
    self.blendFactor    = self.editorView.fields["blendFactor"].value
    self.falloffFactor  = self.editorView.fields["falloffFactor"].value
    self.featureFactor  = self.editorView.fields["featureFactor"].value
    self.diffuseColor   = self.editorView.fields["diffuseColor"].value
    self.texOffsetX     = self.editorView.fields["texOffsetX"].value
    self.texOffsetY     = self.editorView.fields["texOffsetY"].value

    self.updateDelay    = 0.2
    self.applyDelay     = 0.02
end

function TerrainChangeTextureState:Apply(x, z)
    if self:super("Apply", x, z) then

        local opts = {
            x = x - self.size,
            z = z - self.size,
            size = self.size,
            rotation = self.rotation,
            penTexture = self.penTexture,
            paintTexture = self.paintTexture,
            texScale = self.texScale,
            detailTexScale = self.detailTexScale,
            mode = self.mode,
            blendFactor = self.blendFactor,
            falloffFactor = self.falloffFactor,
            featureFactor = self.featureFactor,
            diffuseColor = self.diffuseColor,
            texOffsetX = self.texOffsetX,
            texOffsetY = self.texOffsetY,
        }
        local command = TerrainChangeTextureCommand(opts)
        SCEN_EDIT.commandManager:execute(command)
    end
end

function TerrainChangeTextureState:leaveState()
    self.editorView:Select(0)
end

function TerrainChangeTextureState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        gl.Color(0, 1, 0, 0.3)
        gl.Utilities.DrawGroundCircle(x, z, self.size)
        gl.Color(0, 1, 1, 0.5)
        local rotRad = self.rotation / 180 * math.pi + math.pi/2
        gl.Utilities.DrawGroundHollowCircle(x+self.size * math.sin(rotRad), z+self.size * math.cos(rotRad), self.size / 10, self.size / 12)
        gl.PopMatrix()
    end
end
