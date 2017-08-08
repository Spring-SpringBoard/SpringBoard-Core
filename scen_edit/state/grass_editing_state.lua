GrassEditingState = AbstractHeightmapEditingState:extends{}

function GrassEditingState:init(editorView)
    AbstractHeightmapEditingState.init(self, editorView)
    self.initialDelay = 0
end

function GrassEditingState:GetCommand(x, z, applyAction)
    return TerrainGrassCommand({
        x = x + self.size/2,
		z = z + self.size/2,
        size = self.size,
        shapeName = self.patternTexture,
        rotation = self.rotation,
        amount = applyAction,
    })
end
