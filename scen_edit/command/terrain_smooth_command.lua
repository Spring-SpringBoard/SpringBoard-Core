TerrainSmoothCommand = AbstractTerrainModifyCommand:extends{}
TerrainSmoothCommand.className = "TerrainSmoothCommand"

function TerrainSmoothCommand:init(opts)
    self.className = "TerrainSmoothCommand"
    self.opts = opts
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

function TerrainSmoothCommand:GenerateChanges(params)
    local startX = params.startX
    local startZ = params.startZ
    local parts  = params.parts
    local size   = params.size
    local isUndo = params.isUndo
    local map    = params.map

    local kernel, kernelSize = getKernel(self.opts.sigma)

    local changes = {}

    local halfKernelSize = math.ceil(kernelSize / 2)
    for x = 0, size, Game.squareSize do
        for z = 0, size, Game.squareSize do
            if map[x + z * parts] > 0 then
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
                        changes[x + z * parts] = total - old
                    end
                end
            end
        end
    end

    return changes
end
