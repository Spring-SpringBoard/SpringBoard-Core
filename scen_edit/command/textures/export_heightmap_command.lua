ExportHeightmapCommand = NativeCommand:extends{}
ExportHeightmapCommand.className = "ExportHeightmapCommand"

function ExportHeightmapCommand:init(path, heightmapExtremes)
    self.path = path
    self.heightmapExtremes = heightmapExtremes
end
