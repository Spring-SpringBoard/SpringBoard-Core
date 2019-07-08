ExportGrassCommand = Command:extends{}
ExportGrassCommand.className = "ExportGrassCommand"

function ExportGrassCommand:init(path)
    self.path = path
end


function ExportGrassCommand:execute()
    SB.delayGL(function()
        Spring.CreateDir(Path.GetParentDir(self.path))

        SB.RegisterImageSave()

        Log.Notice("Exporting grass with launcher...")
        local projectPath = SB.project.path
        WG.Connector.Send("TransformSBImage", {
            inPath = VFS.GetFileAbsolutePath(Path.Join(projectPath, "grass.data"):lower()),
            outPath = self.path,
            width = Game.mapSizeX / Game.squareSize + 1,
            height = Game.mapSizeZ / Game.squareSize + 1,
            multiplier = 255,
            packSize = 'uint8'
        })
    end)
end