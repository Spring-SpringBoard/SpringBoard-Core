ExtensionsManager = Observable:extends{}

function ExtensionsManager:init()
    self:loadAll()
    self:LoadAllExtensions()
end

function ExtensionsManager:loadAll()
    self.extsFolders = {}
    for _, subDir in ipairs(Path.SubDirs(SB_EXTS_DIR)) do
        table.insert(self.extsFolders, {
            path = subDir,
            name = Path.ExtractFileName(subDir),
        })
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
    for _, fileName in ipairs(Path.DirList(path)) do
        self:__SyncFile(fileName)
    end
    for _, folderName in ipairs(Path.SubDirs(path)) do
        self:__SyncPathRecursive(folderName)
    end
end

function ExtensionsManager:LoadExtension(extFolder)
    Log.Notice("Loading " .. extFolder.name .. "...")
    SB.IncludeDir(Path.Join(extFolder.path, "ui"))
    SB.IncludeDir(Path.Join(extFolder.path, "cmd"))
    self:__SyncPathRecursive(Path.Join(extFolder.path, "cmd"))
end

function ExtensionsManager:LoadAllExtensions()
    Log.Notice("Loading " .. tostring(#self.extsFolders) .. " extensions...")
    for _, extFolder in ipairs(self.extsFolders) do
        local success, err = pcall(function()
            self:LoadExtension(extFolder)
        end)
        if not success then
            Log.Error(string.format("Failed to load extension: %s", extFolder.name))
            Log.Error(err)
        end
    end
end
