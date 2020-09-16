ExportMetalCommand = Command:extends{}
ExportMetalCommand.className = "ExportMetalCommand"

function ExportMetalCommand:init(path)
    self.path = path
end

function ExportMetalCommand:execute()
    Spring.CreateDir(Path.GetParentDir(self.path))

    local projectPath = SB.project.path
    local METAL_RESOLUTION = 16
    Log.Notice("Exporting metal with launcher...")
    return WG.Connector.Send("TransformSBImage", {
        inPath = Path.Join(projectPath, Project.METAL_FILE),
        outPath = self.path,
        width = Game.mapSizeX / METAL_RESOLUTION,
        height = Game.mapSizeZ / METAL_RESOLUTION,
        -- FIXME: No idea why we divide by 5 tbh. Experimentally deduced
        multiplier = 1.0 / 5.1,
        packSize = 'float32',
        colorType = 'rgb',
        bitDepth = 8
    }, {
        waitForResult = true
    })
end