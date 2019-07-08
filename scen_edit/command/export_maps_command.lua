ExportMapsCommand = Command:extends{}
ExportMapsCommand.className = "ExportMapsCommand"

function ExportMapsCommand:init(path, heightmapExtremes)
    self.path = path
    self.heightmapExtremes = heightmapExtremes
end

function ExportMapsCommand:execute()
    ExportHeightmapCommand(Path.Join(self.path, "heightmap.png"), self.heightmapExtremes):execute()
    ExportDiffuseCommand(Path.Join(self.path, "diffuse.png")):execute()
    ExportShadingTexturesCommand(self.path):execute()
    ExportGrassCommand(self.path, "grass.png"):execute()
    ExportMetalCommand(self.path, "metal.png"):execute()
end
