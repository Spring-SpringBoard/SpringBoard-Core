TerrainSmoothCommand = UndoableCommand:extends{}
TerrainSmoothCommand.className = "TerrainSmoothCommand"

function TerrainSmoothCommand:init(x, z, size, delta)
    self.className = "TerrainSmoothCommand"
    self.x, self.z, self.size = x, z, size
    self.delta = delta
end

--[[
local gaussSize = 10
local totalGauss = 0
local gaussMapping = {}
local sigma = 1

local function initializeGauss()
    for i = 1, gaussSize do
        for j = 1, gaussSize do
            local dx = gaussSize / 2 - i
            local dy = gaussSize / 2 - j
            gaussMapping[i * gaussSize + j] = math.exp(-(dx * dx + dy * dy) / (2 * sigma * sigma)) / math.sqrt(2 * math.pi) * sigma
            totalGauss = totalGauss + gaussMapping[i * gaussSize + j]
        end
    end
end
initializeGauss()

local function getGauss(matrix)
    value = 0
    for i = 1, gaussSize do
        for j = 1, gaussSize do
            value = value + matrix[i * gaussSize + j]
        end
    end
    return value / totalGauss
end
--]]
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
    local parts = 2*size / Game.squareSize
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

function TerrainSmoothCommand:GetHeightMapFunc(isUndo)
    return function()
        local size = self.size
        size = size - size % Game.squareSize
        local map = getMap(size, self.delta)
        local centerX = self.x
        local centerZ = self.z
        local parts = 2*size / Game.squareSize
        local dx = centerX - size
        local dz = centerZ - size
        --Spring.Echo("pre-dx, dz", dx, dz)
        dx = dx - dx % Game.squareSize
        dz = dz - dz % Game.squareSize
        --Spring.Echo("dx, dz", dx, dz)
        if not isUndo then
            self.toUndo = {}
            local totalHeight = 0
            for x = 0, 2*size, Game.squareSize do
                for z = 0, 2*size, Game.squareSize do
                    totalHeight = totalHeight + Spring.GetGroundHeight(x + dx, z + dz)
                end
            end
            local squaresPerLine = 2*size / Game.squareSize + 1
            local averageHeight = totalHeight / squaresPerLine / squaresPerLine
            --Spring.Echo("average", averageHeight)
            local totalDelta = 0
            for x = 0, 2*size, Game.squareSize do
                for z = 0, 2*size, Game.squareSize do
                    local deltaHeight = averageHeight - Spring.GetGroundHeight(x + dx, z + dz)
                    local total = map[x + z * parts] 
                    deltaHeight = deltaHeight * total / 100
                    totalDelta = totalDelta + deltaHeight

                    self.toUndo[x + z * parts] = deltaHeight

                    Spring.AddHeightMap(x + dx, z + dz, deltaHeight)
                end
            end
            --Spring.Echo("totalDelta", totalDelta)
        else
            for x = 0, 2*size, Game.squareSize do
                for z = 0, 2*size, Game.squareSize do
                    local total = self.toUndo[x + z * parts] 
                    Spring.AddHeightMap(x + dx, z + dz, -total)
                end
            end
        end
       --[[ 
        newMap = {}
        Spring.Echo("map part")
        local getLocalArea = function(x, z)
            local area = {}
            for i = 0, gaussSize do
                local xx = x + i
                for j = 0, gaussSize do
                    local zz = z + j
                    area[i * gaussSize + j] = Spring.GetGroundHeight(xx, zz)
                end
            end
            return area
        end
        local smoothArea = 100
        for x = self.x1 - smoothArea, self.x1 + smoothArea, Game.squareSize do
            for z = self.z1 - smoothArea, self.z1 + smoothArea, Game.squareSize do
                local area = getLocalArea(x, z)
                newMap[x * Game.mapSizeX + z] = getGauss(area)
            end
        end
        for x = self.x2 - smoothArea, self.x2 + smoothArea, Game.squareSize do
            for z = self.z1 - smoothArea, self.z1 + smoothArea, Game.squareSize do
                local area = getLocalArea(x, z)
                newMap[x * Game.mapSizeX + z] = getGauss(area)
            end
        end
        for x = self.x1 - smoothArea, self.x1 + smoothArea, Game.squareSize do
            for z = self.z2 - smoothArea, self.z2 + smoothArea, Game.squareSize do
                local area = getLocalArea(x, z)
                newMap[x * Game.mapSizeX + z] = getGauss(area)
            end
        end
        for x = self.x2 - smoothArea, self.x2 + smoothArea, Game.squareSize do
            for z = self.z2 - smoothArea, self.z2 + smoothArea, Game.squareSize do
                local area = getLocalArea(x, z)
                newMap[x * Game.mapSizeX + z] = getGauss(area)
            end
        end
        for point, value in pairs(newMap) do
            local x = point / Game.squareSize
            local z = point % Game.squareSize
            Spring.SetHeightMap(x, z, value)
        end--]]
    end
end

function TerrainSmoothCommand:execute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(false))
end

function TerrainSmoothCommand:unexecute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(true))
end
