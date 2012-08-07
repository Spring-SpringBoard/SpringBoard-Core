TerrainIncreaseCommand = UndoableCommand:extends{}
TerrainIncreaseCommand.className = "TerrainIncreaseCommand"

function TerrainIncreaseCommand:init(x1, z1, x2, z2, delta)
    self.className = "TerrainIncreaseCommand"
    self.x1, self.z1, self.x2, self.z2 = x1, z1, x2, z2
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

function TerrainIncreaseCommand:GetHeightMapFunc(isUndo)
    return function()
        local centerX = (self.x1 + self.x2) / 2
        local centerZ = (self.z1 + self.z2) / 2
        local dx = self.x2 - self.x1
        local dz = self.z2 - self.z1
--        local maxDist = math.sqrt(dx * dx / 4 + dz * dz / 4) * self.delta
        local maxDist = math.min(dx / 2, dz / 2) * self.delta
        local scale = math.abs(10 / maxDist)
        if isUndo then
            scale = -scale
        end
        for x = self.x1, self.x2, Game.squareSize do
            for z = self.z1, self.z2, Game.squareSize do
                local dx = x - centerX
                local dz = z - centerZ
                local dist = math.sqrt(dx * dx + dz * dz)
                local total = (-dist * self.delta + maxDist)
                if total * self.delta >= 0 then
                    total = total * scale
                    Spring.AddHeightMap(x, z, total)
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

function TerrainIncreaseCommand:execute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(false))
end

function TerrainIncreaseCommand:unexecute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(true))
end
