TerrainChangeHeightRectCommand = UndoableCommand:extends{}
TerrainChangeHeightRectCommand.className = "TerrainChangeHeightRectCommand"

function TerrainChangeHeightRectCommand:init(x1, z1, x2, z2, delta)
    self.className = "TerrainChangeHeightRectCommand"
    self.x1, self.z1, self.x2, self.z2 = x1, z1, x2, z2
    self.delta = delta
end

function TerrainChangeHeightRectCommand:GetHeightMapFunc(isUndo)
    return function()
        if not isUndo then
            for x = self.x1, self.x2, Game.squareSize do
                for z = self.z1, self.z2, Game.squareSize do
                    Spring.AddHeightMap(x, z, self.delta)
                end
            end
        else
            for x = self.x1, self.x2, Game.squareSize do
                for z = self.z1, self.z2, Game.squareSize do
                    Spring.AddHeightMap(x, z, -self.delta)
                end
            end
        end
    end
end

function TerrainChangeHeightRectCommand:execute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(false))
end

function TerrainChangeHeightRectCommand:unexecute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(true))
end
