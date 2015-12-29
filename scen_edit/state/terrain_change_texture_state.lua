TerrainChangeTextureState = AbstractMapEditingState:extends{}
SCEN_EDIT.Include("scen_edit/model/texture_manager.lua")

function TerrainChangeTextureState:init(editorView)
    AbstractMapEditingState.init(self, editorView)
    self.paintTexture   = self.editorView.paintTexture
    self.texScale       = self.editorView.fields["texScale"].value
    self.mode           = self.editorView.fields["mode"].value
    self.blendFactor    = self.editorView.fields["blendFactor"].value
    self.falloffFactor  = self.editorView.fields["falloffFactor"].value
    self.featureFactor  = self.editorView.fields["featureFactor"].value
    self.diffuseColor   = self.editorView.fields["diffuseColor"].value
    self.texOffsetX     = self.editorView.fields["texOffsetX"].value
    self.texOffsetY     = self.editorView.fields["texOffsetY"].value
	self.diffuseEnabled = self.editorView.fields["diffuseEnabled"].value
	self.specularEnabled= self.editorView.fields["specularEnabled"].value
	self.normalEnabled  = self.editorView.fields["normalEnabled"].value
	self.voidFactor     = self.editorView.fields["voidFactor"].value

    self.updateDelay    = 0.2
    self.applyDelay     = 0.02
end

function TerrainChangeTextureState:Apply(x, z, voidFactor)
	local opts = {
		x = x - self.size,
		z = z - self.size,
		size = self.size,
		rotation = self.rotation,
		paintTexture = self.paintTexture,
		texScale = self.texScale,
		mode = self.mode,
		blendFactor = self.blendFactor,
		falloffFactor = self.falloffFactor,
		featureFactor = self.featureFactor,
		diffuseColor = self.diffuseColor,
		texOffsetX = self.texOffsetX,
		texOffsetY = self.texOffsetY,
		diffuseEnabled = self.diffuseEnabled,
		specularEnabled = self.specularEnabled,
		normalEnabled = self.normalEnabled,
		voidFactor = voidFactor,
		void = not not self.void,
		smartPaint = not not self.smartPaint,
		textures = self.textures,
	}
	local command = TerrainChangeTextureCommand(opts)
	SCEN_EDIT.commandManager:execute(command)
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
		gl.Blending("alpha_add")
        gl.Color(0, 1, 0, 0.3)
        gl.Utilities.DrawGroundCircle(x, z, self.size)
        gl.Color(0, 1, 1, 0.5)
        local rotRad = math.rad(self.rotation) + math.pi/2
        gl.Utilities.DrawGroundHollowCircle(x+self.size * math.sin(rotRad), z+self.size * math.cos(rotRad), self.size / 10, self.size / 12)
        gl.PopMatrix()
    end
end

function TerrainChangeTextureState:GetApplyParams(x, z, button)
	local voidFactor = self.voidFactor
	if button == 3 then
		voidFactor = -1
	end
	return x, z, voidFactor
end
