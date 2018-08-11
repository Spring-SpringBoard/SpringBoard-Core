TerrainMetalCommand = AbstractTerrainModifyCommand:extends{}
TerrainMetalCommand.className = "TerrainMetalCommand"

function TerrainMetalCommand:init(opts)
    self:__init(opts)
end

local METAL_RESOLUTION = 16

function TerrainMetalCommand:GetChangeFunction()
    return function(x, z, amount)
        local rx = math.round(x/METAL_RESOLUTION)
        local rz = math.round(z/METAL_RESOLUTION)
        local old = Spring.GetMetalAmount(rx, rz)
        Spring.SetMetalAmount(rx, rz, old + amount)
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
    local old, da, d
    for x = 0, size, METAL_RESOLUTION do
        local rx = (x + startX) / METAL_RESOLUTION
        rx = math.round(rx)
        for z = 0, size, METAL_RESOLUTION do
            local rz = (z + startZ) / METAL_RESOLUTION
            rz = math.round(rz)
            d = map[x + z * parts]
            if d > 0 then
                old = Spring.GetMetalAmount(rx, rz)
                if amount ~= old then
                    da = math.min(d, amount - old)
                    changes[x + z * parts] = da
                else
                    da = math.min(d, old - amount)
                    changes[x + z * parts] = -da
                end
            end
        end
    end
    return changes
end
