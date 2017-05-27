TerrainMetalCommand = Command:extends{}
TerrainMetalCommand.className = "TerrainMetalCommand"

function TerrainMetalCommand:init(opts)
    self.className = "TerrainMetalCommand"
    self.opts = opts
end

function TerrainMetalCommand:GetHeightMapFunc(isUndo)
    return function()
        local size = self.opts.size
        local amount
        if (not isUndo and self.opts.addMode) or (isUndo and not self.opts.addMode) then
            amount = 1000
        else
            amount = 0
        end
        local partSize = Game.squareSize / 16
        for x = 0, 2*size, Game.squareSize/16 do
            local dx = size - x
            for z = 0, 2*size, Game.squareSize/16 do
                local dz = size - z
                if dx*dx + dz*dz <= size * size then
                    Spring.SetMetalAmount((x + self.opts.x)/16, (z + self.opts.z)/16, amount)
                end
            end
        end
    end
end

function TerrainMetalCommand:execute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(false))
end

function TerrainMetalCommand:unexecute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(true))
end
