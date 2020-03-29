ExportGrassCommand = Command:extends{}
ExportGrassCommand.className = "ExportGrassCommand"

function ExportGrassCommand:init(path)
    self.path = path
end

function ExportGrassCommand:execute()
    Spring.CreateDir(Path.GetParentDir(self.path))

    local projectPath = SB.project.path
    Log.Notice("Exporting grass with launcher...")
    return WG.Connector.Send("TransformSBImage", {
        inPath = VFS.GetFileAbsolutePath(Path.Join(projectPath, Project.GRASS_FILE)),
        outPath = self.path,
        width = Game.mapSizeX / Game.squareSize / 4,
        height = Game.mapSizeZ / Game.squareSize / 4,
        multiplier = 1,
        packSize = 'uint8',
        colorType = 'rgb',
        bitDepth = 8
    }, {
        waitForResult = true
    })
end