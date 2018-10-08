LoadMetalMapCommand = Command:extends{}
LoadMetalMapCommand.className = "LoadMetalMapCommand"

function LoadMetalMapCommand:init(deltaMap)
    self.deltaMap = deltaMap
end

local METAL_RESOLUTION = 16
function LoadMetalMapCommand:execute()
    --Log.Notice("HEIGHTMAP LOAD")
    if self.deltaMap == nil or #self.deltaMap == 0 then
        return
    end
    Array.LoadFunc(self.deltaMap, function(arrayReader)
        for x = 0, Game.mapSizeX, METAL_RESOLUTION do
            local rx = math.round(x/METAL_RESOLUTION)
            for z = 0, Game.mapSizeZ, METAL_RESOLUTION do
                local rz = math.round(z/METAL_RESOLUTION)
                Spring.SetMetalAmount(rx, rz, arrayReader.Get())
            end
        end
    end)
end
