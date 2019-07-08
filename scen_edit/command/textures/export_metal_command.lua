ExportMetalCommand = Command:extends{}
ExportMetalCommand.className = "ExportMetalCommand"

function ExportMetalCommand:init(path)
    self.path = path
end

function ExportMetalCommand:execute()
    SB.delayGL(function()
        Spring.CreateDir(Path.GetParentDir(self.path))

        SB.RegisterImageSave()

        Log.Notice("Exporting metal with launcher...")
        local projectPath = SB.project.path
        local METAL_RESOLUTION = 16
        WG.Connector.Send("TransformSBImage", {
            inPath = VFS.GetFileAbsolutePath(Path.Join(projectPath, "metal.data"):lower()),
            outPath = self.path,
            width = Game.mapSizeX / METAL_RESOLUTION + 1,
            height = Game.mapSizeZ / METAL_RESOLUTION + 1,
            multiplier = 255,
            packSize = 'float32'
        })
    end)
end