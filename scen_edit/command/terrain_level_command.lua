TerrainLevelCommand = AbstractTerrainModifyCommand:extends{}
TerrainLevelCommand.className = "TerrainLevelCommand"

function TerrainLevelCommand:init(opts)
    self:__init(opts)
end

function TerrainLevelCommand:GetChangeFunction()
    return Spring.AddHeightMap
end

function TerrainLevelCommand:GenerateChanges(params)
    local startX = params.startX
    local startZ = params.startZ
    local parts  = params.parts
    local size   = params.size
    local isUndo = params.isUndo
    local map    = params.map

    local canUpper = self.opts.applyDirID >= 0
    local canLower = self.opts.applyDirID <= 0
    -- Strength should probably never be below 0 for this operation.
    -- We cannot make 0 the minimum value for strength in the UI,
    -- since we're using the same control for both add and set
    -- (although maybe we should separate them, for other reasons as well)
    -- if self.opts.strength < 0 then
    --     canUpper, canLower = canLower, canUpper
    -- end
    local height = self.opts.height

    local changes = {}

    -- localized loop vars
    local old, dh, d
    for x = 0, size, Game.squareSize do
        for z = 0, size, Game.squareSize do
            d = map[x + z * parts]
            if d > 0 then
                old = Spring.GetGroundHeight(x + startX, z + startZ)
                if height > old then
                    if canUpper then
                        dh = math.min(d, height - old)
                        changes[x + z * parts] = dh
                    end
                else
                    if canLower then
                        dh = math.min(d, old - height)
                        changes[x + z * parts] = -dh
                    end
                end
            end
        end
    end
    return changes
end
