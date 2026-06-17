LoadMapCommand = Command:extends{}
LoadMapCommand.className = "LoadMapCommand"

-- Native-only (see nativeCommandsOnly): the Rust module reads the .data file at
-- `path` itself. The Lua execute() below is kept as the original reference/
-- fallback (it does not run while the command is native-only).
function LoadMapCommand:init(heightmap, path)
    self.heightmap = heightmap
    self.path = path
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
