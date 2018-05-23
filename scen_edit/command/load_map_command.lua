LoadMapCommand = Command:extends{}
LoadMapCommand.className = "LoadMapCommand"

function LoadMapCommand:init(deltaMap)
    self.className = "LoadMapCommand"
    self.deltaMap = deltaMap
end

function LoadMapCommand:execute()
    Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1)
    Spring.SetHeightMapFunc(function()
        --Log.Notice("HEIGHTMAP LOAD")
        if self.deltaMap == nil or #self.deltaMap == 0 then
            return
        end
        Array.LoadFunc(self.deltaMap, function(arrayReader)
            for x = 0, Game.mapSizeX, Game.squareSize do
                for z = 0, Game.mapSizeZ, Game.squareSize do
                    Spring.SetHeightMap(x, z, arrayReader.Get())
                end
            end
        end)
    end)
end
