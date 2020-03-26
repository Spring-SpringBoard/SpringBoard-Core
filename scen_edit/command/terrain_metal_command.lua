TerrainMetalCommand = AbstractTerrainModifyCommand:extends{}
TerrainMetalCommand.className = "TerrainMetalCommand"

function TerrainMetalCommand:init(opts)
    self:__init(opts)
end

local spGetMetalAmount = Spring.GetMetalAmount
local spSetMetalAmount = Spring.SetMetalAmount
local mathRound = math.round
local METAL_RESOLUTION = 16

function TerrainMetalCommand:GetChangeFunction()
    return function(x, z, amount)
        local rx = mathRound(x / METAL_RESOLUTION)
        local rz = mathRound(z / METAL_RESOLUTION)
        local old = spGetMetalAmount(rx, rz)
        spSetMetalAmount(rx, rz, old + amount)
    end
end

function TerrainMetalCommand:GetChangeStep()
    return METAL_RESOLUTION
end

function TerrainMetalCommand:GenerateChanges(params)
    local startX = params.startX
    local startZ = params.startZ
    local parts  = params.parts
    local size   = params.size
    local isUndo = params.isUndo
    local map    = params.map

    local amount = self.opts.amount

    local changes = {}

    -- localized loop vars
    local old, delta, kernelMultiplier
    local rx, rz
    for x = 0, size, METAL_RESOLUTION do
        rx = mathRound((x + startX) / METAL_RESOLUTION)
        for z = 0, size, METAL_RESOLUTION do
            rz = mathRound((z + startZ) / METAL_RESOLUTION)
            kernelMultiplier = map[x + z * parts]
            if kernelMultiplier > 0 then
                old = spGetMetalAmount(rx, rz)
                delta = (amount - old) * kernelMultiplier
                if delta ~= 0 then
                    changes[x + z * parts] = delta
                end
            end
        end
    end
    return changes
end
