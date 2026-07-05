ExportMapsCommand = NativeCommand:extends{}
ExportMapsCommand.className = "ExportMapsCommand"

function ExportMapsCommand:init(path, heightmapExtremes)
    self.path = path
    self.heightmapExtremes = heightmapExtremes
end
