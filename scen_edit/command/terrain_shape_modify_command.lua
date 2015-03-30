TerrainShapeModifyCommand = UndoableCommand:extends{}
TerrainShapeModifyCommand.className = "TerrainShapeModifyCommand"

function TerrainShapeModifyCommand:init(x, z, size, delta, shapeName)
    self.className = "TerrainShapeModifyCommand"
    self.x, self.z, self.size = x, z, size
    self.delta = delta
    self.shapeName = shapeName
end
--[[
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
    if not mapsBySize then
        mapsBySize = {}
        maps[size] = mapsBySize
    end

    local map = mapsBySize[delta]
    if not map then
        map = generateMap(size, delta)
        mapsBySize[delta] = map
    end
    return map
end]]

function TerrainShapeModifyCommand:GetHeightMapFunc(isUndo)
    return function()
--         local map = getMap(self.size, self.delta)
        local centerX = self.x
        local centerZ = self.z
        local size = self.size
        local parts = 2*size / Game.squareSize + 1
        local startX = centerX - size
        local startZ = centerZ - size

        local greyscale = SCEN_EDIT.terrainManager:getShape(self.shapeName)
        local res = greyscale.res
        local sizeX = greyscale.sizeX
        local sizeZ = greyscale.sizeZ
        
        local scaleX = sizeX / (2*size)
        local scaleZ = sizeZ / (2*size)
        
        if not isUndo then
            for x = 0, 2*size, Game.squareSize do
                for z = 0, 2*size, Game.squareSize do
                    local rx = math.min(sizeX-1, math.max(0, math.floor(scaleX * x)))
                    local rz = math.min(sizeZ-1, math.max(0, math.floor(scaleZ * z)))
                    local indx = rx * sizeX + rz
                    --Spring.Echo(indx)
                    local diff = res[indx] * self.delta
                    --local diff = map[x + z * parts]
                    Spring.AddHeightMap(x + startX, z + startZ, diff)
                end
            end
        else
            for x = 0, 2*size, Game.squareSize do
                for z = 0, 2*size, Game.squareSize do
                    local rx = math.min(sizeX-1, math.max(0, math.floor(scaleX * x)))
                    local rz = math.min(sizeZ-1, math.max(0, math.floor(scaleZ * z)))
                    local indx = rx * sizeX + rz
                    --Spring.Echo(indx)
                    local diff = res[indx] * self.delta
                    --local diff = map[x + z * parts]
                    Spring.AddHeightMap(x + startX, z + startZ, -diff)
                end
            end
        end
    end
end

function TerrainShapeModifyCommand:execute()
    -- set it only once
    if self.canExecute == nil then
        -- check if shape is available
        self.canExecute = SCEN_EDIT.terrainManager ~= nil and SCEN_EDIT.terrainManager:getShape(self.shapeName) ~= nil
    end
    if self.canExecute then
        Spring.SetHeightMapFunc(self:GetHeightMapFunc(false))
    end
end

function TerrainShapeModifyCommand:unexecute()
    if self.canExecute then
        Spring.SetHeightMapFunc(self:GetHeightMapFunc(true))
    end
end
