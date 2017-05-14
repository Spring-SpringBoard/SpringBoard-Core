TerrainChangeTextureState = AbstractMapEditingState:extends{}
SCEN_EDIT.Include("scen_edit/model/texture_manager.lua")

function TerrainChangeTextureState:init(editorView)
    AbstractMapEditingState.init(self, editorView)
    self.paintTexture   = self.editorView.paintTexture
    self.brushTexture   = self.editorView.brushTexture
    self.texScale       = self.editorView.fields["texScale"].value
    self.mode           = self.editorView.fields["mode"].value
    self.kernelMode     = self.editorView.fields["kernelMode"].value
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
    if not self.brushTexture.diffuse then
        return
    end
    if not self.paintMode or self.paintMode == "" then
        return
    end
    if self.paintMode == "paint" and not self.paintTexture.diffuse then
        return
    end
	local opts = {
		x = x - self.size/2,
		z = z - self.size/2,
		size = self.size,
		rotation = self.rotation,
		paintTexture = self.paintTexture,
        brushTexture = self.brushTexture.diffuse, -- FIXME: shouldn't be called "diffuse"
		texScale = self.texScale,
		mode = self.mode,
        kernelMode = self.kernelMode,
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
        paintMode = self.paintMode,
		textures = self.textures,
	}
	local command = TerrainChangeTextureCommand(opts)
	SCEN_EDIT.commandManager:execute(command)
end

function TerrainChangeTextureState:leaveState()
    self.editorView:Select(0)
end

function TerrainChangeTextureState:DrawWorld()
    if not self.brushTexture.diffuse then
        return
    end
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        local shape = SCEN_EDIT.model.textureManager:GetTexture(self.brushTexture.diffuse)
        self:DrawShape(shape, x, z)
    end
end

function TerrainChangeTextureState:GetApplyParams(x, z, button)
	local voidFactor = self.voidFactor
	if button == 3 then
		voidFactor = -1
	end
	return x, z, voidFactor
end
