TerrainGrassCommand = Command:extends{}
TerrainGrassCommand.className = "TerrainGrassCommand"

function TerrainGrassCommand:init(opts)
    self.className = "TerrainGrassCommand"
    self.opts = opts
end

function TerrainGrassCommand:GetHeightMapFunc(isUndo)
    return function()
        local size = self.opts.size
        local f
        if (not isUndo and self.opts.addMode) or (isUndo and not self.opts.addMode) then
            f = Spring.AddGrass
        else
            f = Spring.RemoveGrass
        end
        for x = 0, 2*size, Game.squareSize/4 do
            local dx = size - x
            for z = 0, 2*size, Game.squareSize/4 do
                local dz = size - z
                if dx*dx + dz*dz <= size * size then
                    f(x + self.opts.x, z + self.opts.z)
                end
            end
        end
    end
end

function TerrainGrassCommand:execute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(false))
end

function TerrainGrassCommand:unexecute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(true))
end
