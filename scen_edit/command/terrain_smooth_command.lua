TerrainSmoothCommand = UndoableCommand:extends{}
TerrainSmoothCommand.className = "TerrainSmoothCommand"

function TerrainSmoothCommand:init(x, z, size, sigma)
    self.className = "TerrainSmoothCommand"
    self.x, self.z, self.size = x, z, size
    self.sigma = sigma
end

local function generateKernel(sigma)
    local size = math.ceil(sigma * 6)
    if size % 2 ~= 1 then
        size = size + 1
    end
    local halfSize = math.ceil(size / 2)

    local kernel = {}

    for x = 1, size do
        for z = 1, size do
            local dx = (halfSize - x)
            local dz = (halfSize - z)
            local d = dx * dx + dz * dz
            local sigmaSquared = sigma * sigma
            kernel[x + (z - 1) * size] = 1 / (2 * math.pi * sigmaSquared ) * math.exp(-d / (2 * sigmaSquared))
        end
    end

    return kernel, size
end

local kernels = {}
local function getKernel(sigma)
    local kernel, kernelSize = nil, nil

    local data = kernels[sigma]
    if data ~= nil then
        kernel, kernelSize = unpack(data)
    else
        kernel, kernelSize = generateKernel(sigma)
        kernels[sigma] = {kernel, kernelSize}
    end
    return kernel, kernelSize
end

function TerrainSmoothCommand:GetHeightMapFunc(isUndo)
    return function()
        local size = self.size
        size = size - size % Game.squareSize

        local kernel, kernelSize = getKernel(self.sigma)

        local centerX = self.x
        local centerZ = self.z
        local parts = 2*size / Game.squareSize + 1
        local startX = centerX - size
        local startZ = centerZ - size
        startX = startX - startX % Game.squareSize
        startZ = startZ - startZ % Game.squareSize
        if not isUndo then
            -- calculate the changes only once so redoing the command is faster
            if self.toDo == nil then
                self.toDo = {}
                local halfKernelSize = math.ceil(kernelSize / 2)
                for x = 0, 2*size, Game.squareSize do
                    for z = 0, 2*size, Game.squareSize do
                        local d = (size - x) * (size - x) + (size - z) * (size - z)
                        if d <= size * size then
                            if x + startX >= halfKernelSize and x + startX < Game.mapSizeX + halfKernelSize and 
                                z + startZ >= halfKernelSize and z + startZ < Game.mapSizeZ + halfKernelSize then
                                local total, totalWeight = 0, 0
                                for i = 1, kernelSize do
                                    for j = 1, kernelSize do
                                        local weight = kernel[i + (j - 1) * kernelSize]
                                        total = total + Spring.GetGroundHeight(x + startX + (i - halfKernelSize) * Game.squareSize, z + startZ + (j - halfKernelSize) * Game.squareSize) * weight
                                        totalWeight = totalWeight + weight
                                    end
                                end
                                total = total / totalWeight

                                local old = Spring.GetGroundHeight(x + startX, z + startZ)
                                if total ~= old then
                                    self.toDo[x + z * parts] = total - old
                                end
                            end
                        end
                    end
                end
            end
            for x = 0, 2*size, Game.squareSize do
                for z = 0, 2*size, Game.squareSize do
                    local delta = self.toDo[x + z * parts] 
                    if delta ~= nil then
                        Spring.AddHeightMap(x + startX, z + startZ, delta)
                    end
                end
            end
        else
            for x = 0, 2*size, Game.squareSize do
                for z = 0, 2*size, Game.squareSize do
                    local delta = self.toDo[x + z * parts] 
                    if delta ~= nil then
                        Spring.AddHeightMap(x + startX, z + startZ, -delta)
                    end
                end
            end
        end
    end
end

function TerrainSmoothCommand:execute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(false))
end

function TerrainSmoothCommand:unexecute()
    Spring.SetHeightMapFunc(self:GetHeightMapFunc(true))
end
