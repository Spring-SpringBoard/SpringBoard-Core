AssetsManager = Observable:extends{}

function AssetsManager:init()
    self:loadAll()
end

function AssetsManager:loadAll()
    self.assetsFolders = {}
    Log.Notice("Scanning asset dirs...")
    for _, subDir in pairs(VFS.SubDirs(SB_ASSETS_DIR)) do
        subDir = subDir:gsub("\\", "/")
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

-- FIXME: do proper asset -> spring conversion
function AssetsManager:ToSpringPath(rootDir, assetPath)
    local path = assetPath
    Log.Debug("[assets_manager] :ToSpringPath()", rootDir, assetPath)
    return path
end

function AssetsManager:ToAssetPath(rootDir, springPath)
    Log.Debug("[assets_manager] :ToAssetPath()", rootDir, springPath)
    local path = springPath:sub(#SB_ASSETS_DIR + 1)
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
            local dirList = VFS.DirList(assetsFolder.path .. rootDir .. dirPath, ...)
            -- FIXME: return asset path rather than true file path
            for _, f in pairs(dirList) do
                f = f:gsub("\\", "/")
                table.insert(files, f)
                Log.Debug("[assets_manager] :DirList() table.insert", f)
            end
        end
    end
    return files
end

function AssetsManager:SubDirs(rootDir, dir, ...)
    local dirs = {}
    Log.Debug("[assets_manager] :SubDirs()", rootDir, dir, ...)
    if dir == '' then
        for _, assetsFolder in pairs(self.assetsFolders) do
            table.insert(dirs, assetsFolder.name .. "/")
            Log.Debug("[assets_manager] :SubDirs() table.insert 1", assetsFolder.name .. "/")
        end
    else
        for _, assetsFolder in pairs(self.assetsFolders) do
            local dirAsset, dirPath = SplitPath(dir, assetsFolder.name)
            if assetsFolder.name .. "/" == dirAsset then
                local subDirs = VFS.SubDirs(assetsFolder.path .. rootDir .. dirPath, ...)
                for _, d in pairs(subDirs) do
                    d = d:gsub("\\", "/")
                    local assetPath = self:ToAssetPath(rootDir, d)
                    local subDirAsset, subDirPath = SplitPath(assetPath, assetsFolder.name)
                    table.insert(dirs, assetPath)
                    Log.Debug("[assets_manager] :SubDirs() table.insert 2", assetPath)
                end
            end
        end
    end
    return dirs
end
