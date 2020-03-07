AssetsManager = Observable:extends{}

function AssetsManager:init()
    self:loadAll()
end

function AssetsManager:loadAll()
    self.assetsFolders = {}
    Log.Notice("Scanning asset dirs at: " .. SB.DIRS.ASSETS .. "...")
    for _, subDir in ipairs(Path.SubDirs(SB.DIRS.ASSETS)) do
        local name = Path.ExtractFileName(subDir)
        table.insert(self.assetsFolders, {
            path = subDir,
            name = name,
        })
        Log.Notice("Detected folder: " .. name)
    end
    Log.Notice("Scan complete. Found " .. #self.assetsFolders .. " asset folders.")
end

local function SplitPath(dir, assetFolderName)
    local dirAsset = dir:sub(1, #(assetFolderName .. "/"))
    local dirPath = dir:sub(#(assetFolderName .. "/") + 1)
    Log.Debug("[assets_manager] SplitPath()", dir, assetFolderName, dirAsset, dirPath)
    return dirAsset, dirPath
end

function AssetsManager:ToSpringPath(rootDir, assetPath)
    local assetDir
    local assetRemaining = ""
    local fsplit = assetPath:find("/")
    if not fsplit then
        assetDir = assetPath
    else
        assetDir = assetPath:sub(1, fsplit)
        assetRemaining = assetPath:sub(fsplit+2)
    end

    local path = Path.Join(SB.DIRS.ASSETS, assetDir, rootDir, assetRemaining)
    Log.Debug("[assets_manager] :ToSpringPath()", rootDir, assetPath)
    return path
end

function AssetsManager:ToAssetPath(rootDir, springPath)
    Log.Debug("[assets_manager] :ToAssetPath()", rootDir, springPath)
    local path = springPath:sub(#SB.DIRS.ASSETS + 1)
    local fsplit = path:find("/")
    if not fsplit then
        Log.Debug("[assets_manager] :ToAssetPath() return \"\"")
        return ""
    end
    local assetFolderName = path:sub(1, fsplit)
    path = assetFolderName .. path:sub(fsplit + 1):sub(#rootDir + 1)
    Log.Debug("[assets_manager] :ToAssetPath() return", path)
    return path
end

function AssetsManager:DirList(rootDir, dir, ...)
    local files = {}
    for _, assetsFolder in pairs(self.assetsFolders) do
        local dirAsset, dirPath = SplitPath(dir, assetsFolder.name)
        if assetsFolder.name .. "/" == dirAsset then
            local dirList = Path.DirList(assetsFolder.path .. rootDir .. dirPath, ...)
            -- FIXME: return asset path rather than true file path
            for _, f in ipairs(dirList) do
                table.insert(files, f)
                Log.Debug("[assets_manager] :DirList() table.insert", f)
            end
        end
    end
    return files
end

function AssetsManager:SubDirs(rootDir, dir, ...)
    Log.Debug("[assets_manager] :SubDirs()", rootDir, dir, ...)
    if dir == '' then
        local dirs = {}
        for _, assetsFolder in ipairs(self.assetsFolders) do
            table.insert(dirs, assetsFolder.name .. "/")
            Log.Debug("[assets_manager] :SubDirs() table.insert 1", assetsFolder.name .. "/")
        end
        return dirs
    end

    local dirs = {}
    for _, assetsFolder in pairs(self.assetsFolders) do
        local dirAsset, dirPath = SplitPath(dir, assetsFolder.name)
        if assetsFolder.name .. "/" == dirAsset then
            local subDirs = Path.SubDirs(assetsFolder.path .. rootDir .. dirPath, ...)
            for _, d in ipairs(subDirs) do
                local assetPath = self:ToAssetPath(rootDir, d)
                local subDirAsset, subDirPath = SplitPath(assetPath, assetsFolder.name)
                table.insert(dirs, assetPath)
                Log.Debug("[assets_manager] :SubDirs() table.insert 2", assetPath)
            end
        end
    end
    return dirs
end
