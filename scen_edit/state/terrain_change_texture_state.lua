TerrainChangeTextureState = AbstractMapEditingState:extends{}
SB.Include("scen_edit/model/texture_manager.lua")

function TerrainChangeTextureState:init(editorView)
    AbstractMapEditingState.init(self, editorView)
    self.brushTexture   = self.editorView.fields["brushTexture"].value
    self.patternTexture = self.editorView.fields["patternTexture"].value
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
	-- self.voidFactor     = self.editorView.fields["voidFactor"].value

    self.updateDelay    = 0.2
    self.applyDelay     = 0.02
end

function TerrainChangeTextureState:Apply(x, z, voidFactor)
    if not self.patternTexture then
        return
    end
    if not self.paintMode or self.paintMode == "" then
        return
    end
    if self.paintMode == "paint" and not self.brushTexture.diffuse then
        return
    end
	local opts = {
		x = x - self.size/2,
		z = z - self.size/2,
		size = self.size,
		rotation = self.rotation,
		brushTexture = self.brushTexture,
        patternTexture = self.patternTexture,
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
		-- voidFactor = voidFactor,
        paintMode = self.paintMode,
		textures = self.textures,
	}
	local command = TerrainChangeTextureCommand(opts)
	SB.commandManager:execute(command)
end

function TerrainChangeTextureState:DrawWorld()
    if not self.patternTexture then
        return
    end
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        local shape = SB.model.textureManager:GetTexture(self.patternTexture)
        self:DrawShape(shape, x, z)
    end
end

-- function TerrainChangeTextureState:GetApplyParams(x, z, button)
-- 	local voidFactor = self.voidFactor
-- 	if button == 3 then
-- 		voidFactor = -1
-- 	end
-- 	return x, z, voidFactor
-- end
