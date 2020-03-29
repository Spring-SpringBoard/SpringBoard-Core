LoadMapCommand = Command:extends{}
LoadMapCommand.className = "LoadMapCommand"

function LoadMapCommand:init(heightmap)
    self.heightmap = heightmap
end

function LoadMapCommand:execute()
    Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1)
    Spring.SetHeightMapFunc(function()
        --Log.Notice("HEIGHTMAP LOAD")
        if self.heightmap == nil or #self.heightmap == 0 then
            Log.Notice("No heightmap")
            return
        end
        Log.Notice("Loading heightmap (" .. tostring(#self.heightmap) .. " bytes)")
        Array.LoadFunc(self.heightmap, function(arrayReader)
            for x = 0, Game.mapSizeX, Game.squareSize do
                for z = 0, Game.mapSizeZ, Game.squareSize do
                    Spring.SetHeightMap(x, z, arrayReader.Get())
                end
            end
        end)
    end)
end
