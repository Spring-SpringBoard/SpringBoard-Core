TerrainLevelCommand = UndoableCommand:extends{}
TerrainLevelCommand.className = "TerrainLevelCommand"

function TerrainLevelCommand:init(x, z, size, height)
    self.className = "TerrainLevelCommand"
    self.x, self.z, self.size, self.height  = x, z, size, height
end

function TerrainLevelCommand:GetHeightMapFunc(isUndo)
    return function()
        local size = self.size
        size = size - size % Game.squareSize
        local centerX = self.x
        local centerZ = self.z
        local parts = 2*size / Game.squareSize + 1
        local startX = centerX - size
        local startZ = centerZ - size
        startX = startX - startX % Game.squareSize
        startZ = startZ - startZ % Game.squareSize
        if not isUndo then
            -- calculate the changes only once so redoing the command is faster
            if self.toDo == nil then
                self.toDo = {}
                for x = 0, 2*size, Game.squareSize do
                    for z = 0, 2*size, Game.squareSize do

                        local d = (size - x) * (size - x) + (size - z) * (size - z)
                        if d <= size * size then
                            if old ~= self.height then
                                local old = Spring.GetGroundHeight(x + startX, z + startZ)
                                self.toDo[x + z * parts] = self.height - old
                            end
                        end
                    end
                end
            end
            for x = 0, 2*size, Game.squareSize do
                for z = 0, 2*size, Game.squareSize do
                    local delta = self.toDo[x + z * parts] 
                    if delta ~= nil then
                        Spring.AddHeightMap(x + startX, z + startZ, delta)
                    end
                end
            end
        else
            for x = 0, 2*size, Game.squareSize do
                for z = 0, 2*size, Game.squareSize do
                    local delta = self.toDo[x + z * parts] 
                    if delta ~= nil then
                        Spring.AddHeightMap(x + startX, z + startZ, -delta)
                    end
                end
            end
        end
    end
end

function TerrainLevelCommand:execute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(false))
end

function TerrainLevelCommand:unexecute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(true))
end
