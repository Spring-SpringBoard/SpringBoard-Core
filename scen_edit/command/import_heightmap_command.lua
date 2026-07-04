ImportHeightmapCommand = NativeCommand:extends{}
ImportHeightmapCommand.className = "ImportHeightmapCommand"

function ImportHeightmapCommand:init(heightmapImage, minHeight, maxHeight)
    self.heightmapImagePath = heightmapImage
    self.minHeight = minHeight
    self.maxHeight = maxHeight
end
