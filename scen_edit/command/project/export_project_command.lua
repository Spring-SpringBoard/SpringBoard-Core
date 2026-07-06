ExportProjectCommand = NativeCommand:extends{}
ExportProjectCommand.className = "ExportProjectCommand"

function ExportProjectCommand:init(archiveDir, path)
    self.path = path
    self.archiveDir = archiveDir
    if Path.GetExt(self.path) ~= ".sdz" then
        self.path = self.path .. ".sdz"
    end
    self.blockUndo = true
end
