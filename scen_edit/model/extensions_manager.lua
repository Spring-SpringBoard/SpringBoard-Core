ExtensionsManager = Observable:extends{}

function ExtensionsManager:init()
    self:loadAll()
    self:LoadAllExtensions()
end

function ExtensionsManager:loadAll()
    self.extsFolders = {}
    for _, subDir in pairs(VFS.SubDirs(SB_EXTS_DIR)) do
        table.insert(self.extsFolders, {
            path = subDir,
            name = Path.ExtractFileName(subDir),
        })
    end
end

local function SplitPath(dir, extFolderName)
    local dirExt = dir:sub(1, #(extFolderName .. "/"))
    local dirPath = dir:sub(#(extFolderName .. "/") + 1)
    return dirExt, dirPath
end

-- FIXME: do proper ext -> spring conversion
function ExtensionsManager:ToSpringPath(rootDir, extPath)
    local path = extPath
    return path
end

function ExtensionsManager:ToExtPath(rootDir, springPath)
    local path = springPath:sub(#SB_EXTS_DIR + 1)
    local fsplit = path:find("/")
    if not fsplit then
        return ""
    end
    local extFolderName = path:sub(1, fsplit)
    path = extFolderName .. path:sub(fsplit + 1):sub(#rootDir + 1)
    return path
end

function ExtensionsManager:DirList(rootDir, dir, ...)
    local files = {}
    for _, extsFolder in pairs(self.extsFolders) do
        local dirExt, dirPath = SplitPath(dir, extsFolder.name)
        if extsFolder.name .. "/" == dirExt then
            local dirList = VFS.DirList(extsFolder.path .. rootDir .. dirPath, ...)
            -- FIXME: return ext path rather than true file path
            for _, f in pairs(dirList) do
                table.insert(files, f)
            end
        end
    end
    return files
end

function ExtensionsManager:SubDirs(rootDir, dir, ...)
    local dirs = {}
    if dir == '' then
        for _, extsFolder in pairs(self.extsFolders) do
            table.insert(dirs, extsFolder.name .. "/")
        end
    else
        for _, extsFolder in pairs(self.extsFolders) do
            local dirExt, dirPath = SplitPath(dir, extsFolder.name)
            if extsFolder.name .. "/" == dirExt then
                local subDirs = VFS.SubDirs(extsFolder.path .. rootDir .. dirPath, ...)
                for _, d in pairs(subDirs) do
                    local extPath = self:ToExtPath(rootDir, d)
                    local subDirExt, subDirPath = SplitPath(extPath, extsFolder.name)
                    table.insert(dirs, extPath)
                end
            end
        end
    end
    return dirs
end

function ExtensionsManager:LoadExtension(extFolder)
    Log.Notice("Loading " .. extFolder.name .. "...")
    SB.IncludeDir(extFolder.path)
end

function ExtensionsManager:LoadAllExtensions()
    Log.Notice("Loading " .. tostring(#self.extsFolders) .. " extensions...")
    for _, extFolder in pairs(self.extsFolders) do
        self:LoadExtension(extFolder)
    end
end
