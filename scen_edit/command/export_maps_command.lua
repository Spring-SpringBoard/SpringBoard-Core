ExportMapsCommand = Command:extends{}
ExportMapsCommand.className = "ExportMapsCommand"

function ExportMapsCommand:init(path, heightmapExtremes)
    self.path = path
    self.heightmapExtremes = heightmapExtremes
end

function ExportMapsCommand:execute()
    return ExportHeightmapCommand(Path.Join(self.path, "heightmap.png"), self.heightmapExtremes):execute()
    :next(function()
        return ExportDiffuseCommand(Path.Join(self.path, "diffuse.png")):execute()
    end)
    :next(function()
        return ExportShadingTexturesCommand(self.path):execute()
    end)
    -- TODO: Readd it but consider that we're already exporting this in ExportAction
    -- :next(function()
    --     return ExportGrassCommand(Path.Join(self.path, "grass.png")):execute()
    -- end)
    :next(function()
        return ExportMetalCommand(Path.Join(self.path, "metal.png")):execute()
    end)
end
