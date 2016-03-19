TerrainLevelCommand = AbstractTerrainModifyCommand:extends{}
TerrainLevelCommand.className = "TerrainLevelCommand"

function TerrainLevelCommand:init(opts)
    self.className = "TerrainLevelCommand"
    self.opts = opts
end

function TerrainLevelCommand:GenerateChanges(params)
    local startX = params.startX
    local startZ = params.startZ
    local parts  = params.parts
    local size   = params.size
    local isUndo = params.isUndo
    local map    = params.map

    local height = self.opts.height

    local changes = {}

    -- localized loop vars
    local old, dh, d
    for x = 0, 2*size, Game.squareSize do
        for z = 0, 2*size, Game.squareSize do
            d = map[x + z * parts]
            if d > 0 then
                old = Spring.GetGroundHeight(x + startX, z + startZ)
                if height > old then
                    dh = math.min(d, height - old)
                    changes[x + z * parts] = dh
                else
                    dh = math.min(d, old - height)
                    changes[x + z * parts] = -dh
                end
            end
        end
    end
    return changes
end