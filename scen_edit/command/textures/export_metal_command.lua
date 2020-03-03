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
    return LauncherImageExporter:Export("TransformSBImage", {
        inPath = VFS.GetFileAbsolutePath(Path.Join(projectPath, Project.METAL_FILE)),
        outPath = self.path,
        width = Game.mapSizeX / METAL_RESOLUTION + 1,
        height = Game.mapSizeZ / METAL_RESOLUTION + 1,
        multiplier = 255,
        packSize = 'float32',
        colorType = 'greyscale',
        bitDepth = 16
    })
end