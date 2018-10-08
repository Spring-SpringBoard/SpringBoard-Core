LoadGrassMapCommand = Command:extends{}
LoadGrassMapCommand.className = "LoadGrassMapCommand"

function LoadGrassMapCommand:init(deltaMap)
    self.deltaMap = deltaMap
end

function LoadGrassMapCommand:execute()
    --Log.Notice("HEIGHTMAP LOAD")
    if self.deltaMap == nil or #self.deltaMap == 0 then
        return
    end
    Array.LoadFunc(self.deltaMap, function(arrayReader)
        for x = 0, Game.mapSizeX, Game.squareSize do
            for z = 0, Game.mapSizeZ, Game.squareSize do
                if arrayReader.Get() == 1 then
                    Spring.AddGrass(x, z)
                else
                    Spring.RemoveGrass(x, z)
                end
            end
        end
    end, "uint8")
end
