TerrainShapeModifyState = AbstractHeightmapEditingState:extends{}

function TerrainShapeModifyState:GetCommand(x, z, strength)
    return TerrainShapeModifyCommand({
        x = x + self.size/2,
		z = z + self.size/2,
        size = self.size,
        strength = strength,
        shapeName = self.paintTexture,
        rotation = self.rotation
    })
end

--gl.Color(0, 0, 1, 0.4)
