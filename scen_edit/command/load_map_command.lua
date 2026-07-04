LoadMapCommand = NativeCommand:extends{}
LoadMapCommand.className = "LoadMapCommand"

function LoadMapCommand:init(heightmap, path)
    self.heightmap = heightmap
    self.path = path
end
