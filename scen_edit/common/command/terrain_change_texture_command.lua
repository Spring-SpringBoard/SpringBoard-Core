TerrainChangeTextureCommand = UndoableCommand:extends{}
TerrainChangeTextureCommand.className = "TerrainChangeTextureCommand"

function TerrainChangeTextureCommand:init(x1, z1, x2, z2, textureId)
    self.className = "TerrainChangeTextureCommand"
    self.x1, self.z1, self.x2, self.z2 = x1, z1, x2, z2
    self.textureId = textureId
end

function TerrainChangeTextureCommand:execute()
    self.oldTexture = Spring.SetMapSquareTerrainType(self.x1, self.z1, self.x2, self.z2, self.textureID)
end

function TerrainChangeTextureCommand:unexecute()
  --  Spring.AdjustHeightMap(self.x1, self.z1, self.x2, self.z2, -self.delta)
end
