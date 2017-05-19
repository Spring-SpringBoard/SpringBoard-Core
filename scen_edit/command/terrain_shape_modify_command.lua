TerrainShapeModifyCommand = AbstractTerrainModifyCommand:extends{}
TerrainShapeModifyCommand.className = "TerrainShapeModifyCommand"

function TerrainShapeModifyCommand:init(opts)
    self.className = "TerrainShapeModifyCommand"
    self.opts = opts
    if self.opts ~= ni then
        local opts = self.opts
        opts.x = math.floor(opts.x)
        opts.z = math.floor(opts.z)
        opts.size = math.floor(opts.size)
    end
end

function TerrainShapeModifyCommand:GenerateChanges(params)
    local startX = params.startX
    local startZ = params.startZ
    local parts  = params.parts
    local size   = params.size
    local isUndo = params.isUndo
    local map    = params.map

    local offsetX = 0
    if startX < 0 then
        -- result of a % b is always a non-negative number
        offsetX = -startX + startX % Game.squareSize
    end
    local offsetZ = 0
    if startZ < 0 then
        -- result of a % b is always a non-negative number
        offsetZ = -startZ + startZ % Game.squareSize
    end

    local multiplier = 1
    if isUndo then
        multiplier = -multiplier
    end

    local changes = {}

    for x = offsetX, size, Game.squareSize do
        for z = offsetZ, size, Game.squareSize do
            local mx, mz = x + startX, z + startZ
            changes[x + z * parts] = map[x + z * parts] * multiplier
--             local dh = map[x + z * parts] * multiplier
--             local gh = Spring.GetGroundHeight(mx, mz)
--             local height = gh + dh
--             local delta =
--             if dh > 0 then
--
--             end
--             height = math.min(gh + dh, maxHeight)
--             height = math.max(height, minHeight)
--             changes[x + z * parts] = height - gh
        end
    end

    return changes
end
