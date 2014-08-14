TerrainIncreaseCommand = UndoableCommand:extends{}
TerrainIncreaseCommand.className = "TerrainIncreaseCommand"

function TerrainIncreaseCommand:init(x, z, size, delta)
    self.className = "TerrainIncreaseCommand"
    self.x, self.z, self.size = x, z, size
    self.delta = delta
end

local multiplierMap = {}
local currentlyGenerated = 0
local function getMultiplier(value)
    multiplier = multiplierMap[value]
    if multiplier == nil then
        multiplier = math.sqrt(value)
        multiplierMap[value] = multiplier
    end
    return multiplier
end

local function generateMap(size, delta)
    local map = {}
    local maxDist = size * delta
    center = size
    local parts = 2*size / Game.squareSize + 1
    local scale = math.abs(10 / maxDist)
    for x = 0, 2*size, Game.squareSize do
        for z = 0, 2*size, Game.squareSize do
            local dx = x - center
            local dz = z - center
            local dist = getMultiplier(dx * dx + dz * dz)
            local total = (-dist * delta + maxDist) * scale
            if total * delta < 0 then
                total = 0
            end
            map[x + z * parts] = total
        end
    end
    return map
end

local maps = {}
local function getMap(size, delta)
    local map = nil

    local mapsBySize = maps[size]
    if mapsBySize then
        map = mapsBySize[delta]
    end
    if not map then
        map = generateMap(size, delta)
        if not mapsBySize then
            mapsBySize = {}
            maps[size] = mapsBySize
        end
        mapsBySize[delta] = map
    end
    return map
end

function TerrainIncreaseCommand:GetHeightMapFunc(isUndo)
    return function()
        local map = getMap(self.size, self.delta)
        local centerX = self.x
        local centerZ = self.z
        local size = self.size
        local parts = 2*size / Game.squareSize + 1
        local startX = centerX - size
        local startZ = centerZ - size
        if not isUndo then
            for x = 0, 2*size, Game.squareSize do
                for z = 0, 2*size, Game.squareSize do
                    local total = map[x + z * parts]
                    Spring.AddHeightMap(x + startX, z + startZ, total)
                end
            end
        else
            for x = 0, 2*size, Game.squareSize do
                for z = 0, 2*size, Game.squareSize do
                    local total = map[x + z * parts] 
                    Spring.AddHeightMap(x + startX, z + startZ, -total)
                end
            end
        end
    end
end

function TerrainIncreaseCommand:execute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(false))
end

function TerrainIncreaseCommand:unexecute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(true))
end
