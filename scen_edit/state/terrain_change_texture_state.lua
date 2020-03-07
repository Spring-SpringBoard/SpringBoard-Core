SB.Include(Path.Join(SB.DIRS.SRC, 'model/texture_manager.lua'))

TerrainChangeTextureState = AbstractMapEditingState:extends{}

function TerrainChangeTextureState:init(editorView)
    AbstractMapEditingState.init(self, editorView)
    self.brushTexture   = self.editorView.fields["brushTexture"].value
    self.patternTexture = self.editorView.fields["patternTexture"].value
    self.texScale       = self.editorView.fields["texScale"].value
    self.mode           = self.editorView.fields["mode"].value
    self.dntsIndex      = self.editorView.fields["dntsIndex"].value
    self.kernelMode     = self.editorView.fields["kernelMode"].value
    self.strength       = self.editorView.fields["strength"].value
    self.falloffFactor  = self.editorView.fields["falloffFactor"].value
    self.featureFactor  = self.editorView.fields["featureFactor"].value
    self.diffuseColor   = self.editorView.fields["diffuseColor"].value
    self.texOffsetX     = self.editorView.fields["texOffsetX"].value
    self.texOffsetY     = self.editorView.fields["texOffsetY"].value
    self.texRotation    = self.editorView.fields["texRotation"].value

    for _, fname in pairs(self.editorView.matFieldNames) do
        self[fname] = self.editorView.fields[fname].value
    end

    self.voidFactor     = self.editorView.fields["voidFactor"].value
    self.exclusive      = self.editorView.fields["exclusive"].value
    self.value          = self.editorView.fields["value"].value

    self.updateDelay    = 0.2
    self.applyDelay     = 0.02
end

function TerrainChangeTextureState:Apply(x, z, applyAction)
    if not self.patternTexture then
        return
    end
    if not self.paintMode or self.paintMode == "" then
        return
    end
    if self.paintMode == "paint" then
        if not self.brushTexture then
            return
        end

        local hasMat = false
        -- luacheck: ignore 512
        for _, fname in pairs(self.brushTexture) do
            hasMat = true
            break
        end
        if not hasMat then
            return
        end
    end
    local voidFactor = self.voidFactor * applyAction
    local colorIndex = self.dntsIndex + 1
    if colorIndex then
        colorIndex = colorIndex * applyAction
    end
    local exclusive = 0
    if self.exclusive then
        exclusive = 1
    end

    local opts = {
        x = x - self.size/2,
        z = z - self.size/2,
        size = self.size,
        brushTexture = self.brushTexture,
        patternTexture = self.patternTexture,
        patternRotation = math.rad(self.rotation),
        texScale = self.texScale,
        mode = self.mode,
        kernelMode = self.kernelMode,
        strength = self.strength,
        falloffFactor = self.falloffFactor,
        featureFactor = self.featureFactor,
        diffuseColor = self.diffuseColor,
        texOffsetX = self.texOffsetX,
        texOffsetY = self.texOffsetY,
        rotation = math.rad(self.texRotation),
        voidFactor = voidFactor,
        paintMode = self.paintMode,
        colorIndex = colorIndex,
        exclusive = exclusive,
        value = self.value,
    }
    for _, fname in pairs(self.editorView.matFieldNames) do
        opts[fname] = self[fname]
    end

    local command = TerrainChangeTextureCommand(opts)
    SB.commandManager:execute(command)
end

function TerrainChangeTextureState:GetApplyParams(x, z, button)
    local applyAction = 1
    if button == 3 then
        applyAction = -1
    end
    return x, z, applyAction
end
