LoadGrassMapCommand = Command:extends{}
LoadGrassMapCommand.className = "LoadGrassMapCommand"

function LoadGrassMapCommand:init(deltaMap)
    self.deltaMap = deltaMap
end

function LoadGrassMapCommand:execute()
    if self.deltaMap == nil or #self.deltaMap == 0 then
        return
    end
    Array.LoadFunc(self.deltaMap, function(arrayReader)
        for x = 0, Game.mapSizeX - 1, Game.squareSize * 4 do
            for z = 0, Game.mapSizeZ - 1, Game.squareSize * 4 do
                if arrayReader.Get() == 1 then
                    Spring.AddGrass(x, z)
                else
                    Spring.RemoveGrass(x, z)
                end
            end
        end
    end, "uint8")
end
