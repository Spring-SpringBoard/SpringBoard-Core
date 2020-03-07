ExtensionsManager = Observable:extends{}

function ExtensionsManager:init()
    self:loadAll()
    self:LoadAllExtensions()
end

function ExtensionsManager:loadAll()
    self.extsFolders = {}
    for _, subDir in ipairs(Path.SubDirs(SB.DIRS.EXTS)) do
        table.insert(self.extsFolders, {
            path = subDir,
            name = Path.ExtractFileName(subDir),
        })
    end
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
    -- SB.view.tabbedWindow:UpdateEditorRegistry()
end

function ExtensionsManager:ReloadExtension(extFolder)
    Log.Notice("Reloading extension \"" .. extFolder.name .. "\" (" .. extFolder.path .. ")...")
    self:__ReloadExtension(extFolder)
end

function ExtensionsManager:LoadExtension(extFolder)
    Log.Notice("Loading extension \"" .. extFolder.name .. "\" (" .. extFolder.path .. ")...")
    self:__ReloadExtension(extFolder)
end

local env
function ExtensionsManager:__ReloadExtension(extFolder)
    -- env = {
    --     SB = SB,
    --     Path = Path,
    --     Array = Array,
    --     Editor = Editor,
    --     NumericField = NumericField,
    --     StringField = StringField,
    --     Command = Command
    --     -- TODO: etc.
    -- }
    -- TODO: Use a custom environment so reloading extensions is done cleanly
    SB.IncludeDir(Path.Join(extFolder.path, "ui"), env, VFS.RAW, true)
    SB.IncludeDir(Path.Join(extFolder.path, "cmd"), env, VFS.RAW, true)
    self:__SyncPathRecursive(Path.Join(extFolder.path, "cmd"))
end

function ExtensionsManager:__SyncFile(path)
    SB.delay(function()
        local fileData = VFS.LoadFile(path, VFS.RAW)
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
