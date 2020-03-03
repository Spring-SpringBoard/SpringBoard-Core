MetalEditingState = AbstractHeightmapEditingState:extends{}

function MetalEditingState:init(editorView)
    AbstractHeightmapEditingState.init(self, editorView)
    self.amount = self.editorView.fields["amount"].value
    self.initialDelay = 0
end

function MetalEditingState:GetCommand(x, z, applyAction)
    return TerrainMetalCommand({
        x = x + self.size/2,
        z = z + self.size/2,
        size = self.size,
        shapeName = self.patternTexture,
        rotation = self.rotation,
        amount = self.amount * applyAction
    })
end

function MetalEditingState:GetApplyParams(x, z, button)
    local applyAction = 1
    if button == 3 then
        applyAction = 0
    end
    return x, z, applyAction
end
