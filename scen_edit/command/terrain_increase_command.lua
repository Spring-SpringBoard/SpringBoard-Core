TerrainIncreaseCommand = UndoableCommand:extends{}
TerrainIncreaseCommand.className = "TerrainIncreaseCommand"

function TerrainIncreaseCommand:init(x, z, size, delta)
    self.className = "TerrainIncreaseCommand"
    self.x, self.z, self.size = x, z, size
    self.delta = delta
end

local function generateMap(size, delta)
    local map = {}
    local maxDist = size * delta
    local center = size
    local parts = 2*size / Game.squareSize + 1
    local scale = math.abs(10 / maxDist)
    for x = 0, 2*size, Game.squareSize do
        for z = 0, 2*size, Game.squareSize do
            local dx = x - center
            local dz = z - center
            local dist = math.sqrt(dx * dx + dz * dz)
            local total = (-dist * delta + maxDist) * scale
            if total * delta < 0 then
                total = 0
            end
            map[x + z * parts] = total * math.abs(delta)
        end
    end
    return map
end

local maps = {}
local function getMap(size, delta)
    local map = nil

    local mapsBySize = maps[size]
    if not mapsBySize then
        mapsBySize = {}
        maps[size] = mapsBySize
    end
    map = mapsBySize[delta]
    if not map then
        map = generateMap(size, delta)
        mapsBySize[delta] = map
    end
    return map
end

function TerrainIncreaseCommand:GetHeightMapFunc(isUndo)
    return function()
        local map = getMap(self.size, self.delta)
        local size = self.size
        local parts = 2*size / Game.squareSize + 1
        local startX = self.x - size
        local startZ = self.z - size
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
