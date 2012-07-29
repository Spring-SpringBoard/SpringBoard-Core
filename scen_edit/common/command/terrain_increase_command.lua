TerrainIncreaseCommand = UndoableCommand:extends{}
TerrainIncreaseCommand.className = "TerrainIncreaseCommand"

function TerrainIncreaseCommand:init(x1, z1, x2, z2, delta)
    self.className = "TerrainIncreaseCommand"
    self.x1, self.z1, self.x2, self.z2 = x1, z1, x2, z2
    self.delta = delta
end

function TerrainIncreaseCommand:execute()
    Spring.AdjustHeightMap(self.x1, self.z1, self.x2, self.z2, self.delta)
end

function TerrainIncreaseCommand:unexecute()
    Spring.AdjustHeightMap(self.x1, self.z1, self.x2, self.z2, -self.delta)
end
