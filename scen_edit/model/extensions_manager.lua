ExtensionsManager = Observable:extends{}

function ExtensionsManager:init()
    self:loadAll()
    self:LoadAllExtensions()
end

function ExtensionsManager:loadAll()
    self.extsFolders = {}
    self.extsCount = 0
    for _, subDir in pairs(VFS.SubDirs(SB_EXTS_DIR)) do
        table.insert(self.extsFolders, {
            path = subDir,
            name = Path.ExtractFileName(subDir),
        })
        self.extsCount = self.extsCount + 1
    end
end

function ExtensionsManager:__SyncFile(path)
    SB.delay(function()
        local fileData = VFS.LoadFile(path)
        local cmd = SyncFileCommand(fileData)
        SB.commandManager:execute(cmd)
    end)
end

function ExtensionsManager:__SyncPathRecursive(path)
    for _, fileName in pairs(VFS.DirList(path)) do
        self:__SyncFile(fileName)
    end
    for _, folderName in pairs(VFS.SubDirs(path)) do
        self:SyncPath(folderName)
    end
end

function ExtensionsManager:LoadExtension(extFolder)
    Log.Notice("Loading " .. extFolder.name .. "...")
    SB.IncludeDir(Path.Join(extFolder.path, "ui"))
    SB.IncludeDir(Path.Join(extFolder.path, "cmd"))
    self:__SyncPathRecursive(Path.Join(extFolder.path, "cmd"))
end

function ExtensionsManager:LoadAllExtensions()
    Log.Notice("Loading " .. tostring(self.extsCount) .. " extensions...")
    for _, extFolder in pairs(self.extsFolders) do
        self:LoadExtension(extFolder)
    end
end
