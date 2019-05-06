ExportProjectCommand = Command:extends{}
ExportProjectCommand.className = "ExportProjectCommand"

function ExportProjectCommand:init(archiveDir, path)
    self.path = path
    self.archiveDir = archiveDir
    if Path.GetExt(self.path) ~= ".sdz" then
        self.path = self.path .. ".sdz"
    end
end

function ExportProjectCommand:execute()
    if VFS.FileExists(self.path, VFS.RAW) then
        Log.Notice("File exists, trying to remove...")
        os.remove(self.path)
    end
    assert(not VFS.FileExists(self.path, VFS.RAW), "File already exists")

    -- local projectDir = SB.project.path
    Log.Notice("Compressing folder...")
    VFS.CompressFolder(self.archiveDir, "zip", self.path)
end
