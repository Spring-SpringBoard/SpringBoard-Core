TerrainGrassCommand = AbstractTerrainModifyCommand:extends{}
TerrainGrassCommand.className = "TerrainGrassCommand"

function TerrainGrassCommand:init(opts)
    self:__init(opts)
end

function TerrainGrassCommand:GetChangeFunction()
    return function(x, z, amount)
        if amount == 1 then
            Spring.AddGrass(x, z)
        else
            Spring.RemoveGrass(x, z)
        end
    end
end

function TerrainGrassCommand:GenerateChanges(params)
    local startX = params.startX
    local startZ = params.startZ
    local parts  = params.parts
    local size   = params.size
    local isUndo = params.isUndo
    local map    = params.map

    local amount = self.opts.amount
    if amount < 0 then
        amount = 0
    end

    local changes = {}

    -- localized loop vars
    local d
    for x = 0, size, Game.squareSize * 4 do
        for z = 0, size, Game.squareSize * 4 do
            d = map[x + z * parts]
            if d >= 0.5 then
                local old = Spring.GetGrass(startX + x, startZ + z)
                if old ~= amount then
                    changes[x + z * parts] = amount - old
                end
            end
        end
    end
    return changes
end
