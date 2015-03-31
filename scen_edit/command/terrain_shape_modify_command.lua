TerrainShapeModifyCommand = UndoableCommand:extends{}
TerrainShapeModifyCommand.className = "TerrainShapeModifyCommand"

function TerrainShapeModifyCommand:init(x, z, size, delta, shapeName)
    self.className = "TerrainShapeModifyCommand"
    self.x, self.z, self.size = x, z, size
    self.delta = delta
    self.shapeName = shapeName
end

local function generateMap(size, delta, shapeName)
    local greyscale = SCEN_EDIT.terrainManager:getShape(shapeName)
    local sizeX, sizeZ = greyscale.sizeX, greyscale.sizeZ
    local map = { sizeX = sizeX, sizeZ = sizeZ }
    local res = greyscale.res

    local scaleX = sizeX / (2*size)
    local scaleZ = sizeZ / (2*size)
    local parts = 2*size / Game.squareSize + 1

    local function getIndex(x, z)
        local rx = math.min(sizeX-1, math.max(0, math.floor(scaleX * x)))
        local rz = math.min(sizeZ-1, math.max(0, math.floor(scaleZ * z)))
        local indx = rx * sizeX + rz
        return indx
    end
    -- interpolates between four nearest points based on their distance
    local function interpolate(x, z)
        local rxRaw = scaleX * x
        local rzRaw = scaleZ * z
        local rx = math.floor(rxRaw)
        local rz = math.floor(rzRaw)
        local indx = rx * sizeX + rz

        local i = (rxRaw > rx) and 1 or -1
        local j = (rzRaw > rz) and 1 or -1
        local dx = 1 - (rxRaw - rx)
        local dz = 1 - (rzRaw - rz)

        local value = res[indx] * dx * dz 
                    + res[indx + i * sizeX] * (1 - dx) * dz 
                    + res[indx + j] * dx * (1 - dz) 
                    + res[indx + i * sizeX + j] * (1 - dx) * (1 - dz)

        local w = dx * dx + (1 - dx) * dz + dx * (1 - dz) + (1 - dx) * (1 - dz)
        return value
    end

    for x = 0, 2*size, Game.squareSize do
        for z = 0, 2*size, Game.squareSize do
            local diff
            local indx = getIndex(x, z)
            if indx > sizeX + 1 and indx < sizeX * (sizeX - 1) - 1 then
                diff = interpolate(x, z)
            else
                diff = res[indx]
            end
            map[x + z * parts] = diff * delta
        end
    end
    return map
end

local maps = {}
local function getMap(size, delta, shapeName)
    local map = nil

    local mapsByShape = maps[shapeName]
    if not mapsByShape then
        mapsByShape = {}
        maps[size] = mapsByShape
    end

    local mapsBySize = mapsByShape[size]
    if not mapsBySize then
        mapsBySize = {}
        mapsByShape[size] = mapsBySize
    end

    local map = mapsBySize[delta]
    if not map then
        map = generateMap(size, delta, shapeName)
        mapsBySize[delta] = map
    end
    return map
end

function TerrainShapeModifyCommand:GetHeightMapFunc(isUndo)
    return function()
        local map = getMap(self.size, self.delta, self.shapeName)
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
