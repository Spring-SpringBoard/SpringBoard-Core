AssetsManager = Observable:extends{}

function AssetsManager:init()
    self:loadAll()
end

function AssetsManager:loadAll()
    self.assetsFolders = {}
    for _, subDir in pairs(VFS.SubDirs(SB_ASSETS_DIR)) do
        table.insert(self.assetsFolders, {
            path = subDir,
            name = Path.ExtractFileName(subDir),
        })
    end
end

local function SplitPath(dir, assetFolderName)
    local dirAsset = dir:sub(1, #(assetFolderName .. "/"))
    local dirPath = dir:sub(#(assetFolderName .. "/") + 1)
    return dirAsset, dirPath
end

-- FIXME: do properly asset -> spring conversion
function AssetsManager:ToSpringPath(rootDir, assetPath)
    local path = assetPath
    return path
end

function AssetsManager:ToAssetPath(rootDir, springPath)
    local path = springPath:sub(#SB_ASSETS_DIR + 1)
    local fsplit = path:find("/")
    local assetFolderName = path:sub(1, fsplit)
    path = assetFolderName .. path:sub(fsplit + 1):sub(#rootDir + 1)
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
                table.insert(files, f)
            end
        end
    end
    return files
end

function AssetsManager:SubDirs(rootDir, dir, ...)
    local dirs = {}
    if dir == '' then
        for _, assetsFolder in pairs(self.assetsFolders) do
            table.insert(dirs, assetsFolder.name .. "/")
        end
    else
        for _, assetsFolder in pairs(self.assetsFolders) do
            local dirAsset, dirPath = SplitPath(dir, assetsFolder.name)
            if assetsFolder.name .. "/" == dirAsset then
                local subDirs = VFS.SubDirs(assetsFolder.path .. rootDir .. dirPath, ...)
                for _, d in pairs(subDirs) do
                    local assetPath = self:ToAssetPath(rootDir, d)
                    local subDirAsset, subDirPath = SplitPath(assetPath, assetsFolder.name)
                    table.insert(dirs, assetPath)
                end
            end
        end
    end
    return dirs
end
