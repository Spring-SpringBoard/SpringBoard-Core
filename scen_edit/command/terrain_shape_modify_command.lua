TerrainShapeModifyCommand = UndoableCommand:extends{}
TerrainShapeModifyCommand.className = "TerrainShapeModifyCommand"

function TerrainShapeModifyCommand:init(x, z, size, delta, shapeName, rotation)
    self.className = "TerrainShapeModifyCommand"
    self.x, self.z, self.size = x, z, size
    if self.x ~= nil and self.z ~= nil and self.size then
        self.x = math.floor(self.x)
        self.z = math.floor(self.z)
        self.size = math.floor(self.size)
    end
    self.delta = delta
    self.shapeName = shapeName
    self.rotation = rotation
end

local function rotate(x, y, angle)
    return x * math.cos(angle) - y * math.sin(angle),
           x * math.sin(angle) + y * math.cos(angle)
end

local function generateMap(size, delta, shapeName, rotation)
    local greyscale = SCEN_EDIT.model.terrainManager:getShape(shapeName)
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

    local angle = math.rad(rotation)
    for x = 0, 2*size, Game.squareSize do
        for z = 0, 2*size, Game.squareSize do
            local rx, rz = x - size, z - size
            rx, rz = rotate(rx, rz, angle)
            rx, rz = rx + size, rz + size
            local diff
            local indx = getIndex(rx, rz)
            if indx > sizeX + 1 and indx < sizeX * (sizeX - 1) - 1 then
                diff = interpolate(rx, rz)
            else
                diff = res[indx]
            end
            map[x + z * parts] = diff * delta
        end
    end
    return map
end

local maps = {}
--  FIXME: ugly, rework
local function getMap(size, delta, shapeName, rotation)
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
    
    local mapsByRotation = mapsBySize[size]
    if not mapsByRotation then
        mapsByRotation = {}
        mapsBySize[rotation] = mapsByRotation
    end

    local map = mapsByRotation[delta]
    if not map then
        map = generateMap(size, delta, shapeName, rotation)
        mapsByRotation[delta] = map
    end
    return map
end

function TerrainShapeModifyCommand:GetHeightMapFunc(isUndo)
    return function()
        local map = getMap(self.size, self.delta, self.shapeName, self.rotation)
        local size = self.size
        local parts = 2*size / Game.squareSize + 1
        local startX = self.x - size
        local startZ = self.z - size

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

        for x = offsetX, 2*size, Game.squareSize do
            for z = offsetZ, 2*size, Game.squareSize do
                Spring.AddHeightMap(x + startX, z + startZ, 
                    map[x + z * parts] * multiplier)
            end
        end
    end
end

function TerrainShapeModifyCommand:execute()
    -- set it only once
    if self.canExecute == nil then
        -- check if shape is available
        self.canExecute = SCEN_EDIT.model.terrainManager:getShape(self.shapeName) ~= nil
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
