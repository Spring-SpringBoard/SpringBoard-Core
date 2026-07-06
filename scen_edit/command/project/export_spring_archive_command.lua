ExportSpringArchiveCommand = NativeCommand:extends{}
ExportSpringArchiveCommand.className = "ExportSpringArchiveCommand"

function ExportSpringArchiveCommand:init(path, heightmapExtremes)
    self.path = path
    self.heightmapExtremes = heightmapExtremes
    self.projectPath = SB.project.path
    self.projectName = SB.project.name
    self.writePath = SB.DIRS.WRITE_PATH
    self.blockUndo = true
end
