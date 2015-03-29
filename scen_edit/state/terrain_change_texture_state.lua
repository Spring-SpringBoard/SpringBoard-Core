TerrainChangeTextureState = AbstractMapEditingState:extends{}
SCEN_EDIT.Include("scen_edit/model/texture_manager.lua")

function TerrainChangeTextureState:init(terrainEditorView)
    self.terrainEditorView = terrainEditorView
    self.paintTexture   = self.terrainEditorView.paintTexture
    self.penTexture     = self.terrainEditorView.penTexture
    self.size           = self.terrainEditorView.fields["size"].value
    self.texScale       = self.terrainEditorView.fields["texScale"].value
    self.detailTexScale = self.terrainEditorView.fields["detailTexScale"].value
    self.mode           = self.terrainEditorView.fields["mode"].value
    self.blendFactor    = self.terrainEditorView.fields["blendFactor"].value
    self.falloffFactor  = self.terrainEditorView.fields["falloffFactor"].value
    self.diffuseColor   = self.terrainEditorView.fields["diffuseColor"].value

    self.minSize = self.terrainEditorView.fields["size"].minValue
    self.maxSize = self.terrainEditorView.fields["size"].maxValue

    if SCEN_EDIT.textureManager == nil then
        SCEN_EDIT.textureManager = TextureManager()
    end
end

function TerrainChangeTextureState:Apply(x, z)
    if self:super("Apply", x, z) then

        local opts = {
            x = x - self.size,
            z = z - self.size,
            size = self.size,
            penTexture = self.penTexture,
            paintTexture = self.paintTexture,
            texScale = self.texScale,
            detailTexScale = self.detailTexScale,
            mode = self.mode,
            blendFactor = self.blendFactor,
            falloffFactor = self.falloffFactor,
            diffuseColor = self.diffuseColor,
        }
        local command = TerrainChangeTextureCommand(opts)
        SCEN_EDIT.commandManager:execute(command)
    end
end

function TerrainChangeTextureState:leaveState()
    self.terrainEditorView:Select(0)
end

function TerrainChangeTextureState:MouseWheel(up, value)
    if self:super("MouseWheel", up, value) then
        self.terrainEditorView:SetNumericField("size", size)
        return true
    end
end

-- use mouse move instead of update
function TerrainChangeTextureState:MouseMove()
    self:super("Update")
end
function TerrainChangeTextureState:Update()
end

function TerrainChangeTextureState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        gl.Color(0, 1, 0, 0.3)
        --gl.DepthTest(true)
        gl.Utilities.DrawGroundCircle(x, z, self.size)
        gl.PopMatrix()
    end
end
