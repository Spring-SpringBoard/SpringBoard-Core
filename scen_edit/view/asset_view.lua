SB.Include(Path.Join(SB.DIRS.SRC, 'view/grid_view.lua'))

AssetView = GridView:extends{}

SB._assetViews = {}
setmetatable(SB._assetViews, { __mode = 'v' })
function AssetView:init(tbl)
    table.insert(SB._assetViews, self)
    local defaults = {
        showDirs = true,
        imageFolderUp = nil,
        imageFolder = nil,
        showPath = true,
    }
    tbl = Table.Merge(defaults, tbl)
    GridView.init(self, tbl)

    self.rootDir = tbl.rootDir
    self.showDirs = tbl.showDirs
    self.imageFolder = tbl.imageFolder or self._fakeControl.imageFolder
    self.imageFolderUp = tbl.imageFolderUp or self._fakeControl.imageFolderUp
    self.openProjectsAsFiles = tbl.openProjectsAsFiles
    self.OnDblClickItem = tbl.OnDblClickItem or { function() end }

    -- FIXME: Cleanup double click handling hack
    self.__previousDoubleClickTime = Spring.GetTimer()

    self.layoutPanel.MouseDblClick = function(ctrl, x, y, button, mods)
        if button ~= 1 then
            return
        end
        local cx,cy = ctrl:LocalToClient(x,y)
        local itemIdx = ctrl:GetItemIndexAt(cx,cy)

        if itemIdx < 0 then return end

        local item = self.items[itemIdx]
        if item == nil then
            return
        end

        self:DoubleClickItem(item)

        return ctrl
    end
    if self.showPath then
        self.scrollPanel:SetPos(nil, 20)
        self.lblPath = Label:New {
            x = 35,
            y = 3,
            width = 100,
            height = 20,
            caption = "",
            parent = self.holderControl,
            font = {
                color = {0.7, 0.7, 0.7, 1.0},
            },
        }
        self.btnUp = Button:New {
            x = 5,
            y = 2,
            width = 18,
            height = 18,
            caption = "",
            parent = self.holderControl,
            padding = {0, 0, 0, 0},
            children = {
                Image:New {
                    x = 0,
                    y = 0,
                    width = "100%",
                    height = "100%",
                    margin = {0, 0, 0, 0},
                    file = self.imageFolderUp,
                }
            },
            OnClick = {
                function()
                    self:SetDir(Path.GetParentDir(self.dir))
                end
            },
        }
        if self.rootDir then
            self.lblRootDir = Label:New {
                right = 5,
                y = 3,
                width = 100,
                height = 20,
                caption = "Root: " .. tostring(self.rootDir),
                parent = self.holderControl,
                font = {
                    color = {0.7, 0.7, 0.7, 1.0},
                },
            }
        end
    end
    self:SetDir(tbl.dir or '')
end

-- FIXME: Cleanup double click handling hack
function AssetView:DoubleClickItem(item)
    local now = Spring.GetTimer()
    if Spring.DiffTimers(now, self.__previousDoubleClickTime) < 0.45 then
        return
    end
    self.__previousDoubleClickTime = now

    if item.isFolder and (not item.isProject or not self.openProjectsAsFiles) then
        self:SetDir(item.path)
    else
        CallListeners(self.OnDblClickItem, item)
    end
end

function AssetView:SetDir(directory)
    self.layoutPanel:DeselectAll()
    self.dir = directory
    if self.lblPath then
        self.lblPath:SetCaption(self.dir)
    end
--     MaterialBrowser.lastDir = self.dir
    self:ScanDir()
end

function AssetView:ScanDir()
    self:ScanDirStarted()

    local files = self:_DirList()
    self.files = {}
    for _, file in pairs(files) do
        local ext = (Path.GetExt(file) or ""):lower()
        if self:FilterFile(file) then
            table.insert(self.files, file)
        end
    end
    self.dirs = self:_SubDirs()

    self:ScanDirFinished()

    self:StartMultiModify()
    self:ClearItems()

    --// add dirs at top
    if self.showDirs then
        for _, dir in pairs(self.dirs) do
            self:AddFolder(dir)
        end
    end
    self:PopulateItems()

    self:EndMultiModify()
end

function AssetView:SelectAsset(path)
    if path == nil then
        self:DeselectAll()
        return
    end

    local assetPath = self:_ToAssetPath(path)
    local dir = Path.GetParentDir(assetPath)
    self:SetDir(dir)
    for itemIdx, item in pairs(self:GetAllItems()) do
        if item.path == path then
            self:SelectItem(itemIdx)
        end
    end
end

function AssetView:_DirList()
    if self.rootDir then
        return SB.model.assetsManager:DirList(self.rootDir, self.dir, "*")
    else
        return Path.DirList(self.dir, "*")
    end
end

function AssetView:_SubDirs()
    if self.rootDir then
        return SB.model.assetsManager:SubDirs(self.rootDir, self.dir, "*")
    else
        return Path.SubDirs(self.dir, "*")
    end
end

function AssetView:_ToAssetPath(path)
    if self.rootDir then
        return SB.model.assetsManager:ToAssetPath(self.rootDir, path)
    else
        return path
    end
end

-- Override
function AssetView:ScanDirStarted()
end

function AssetView:ScanDirFinished()
end

function AssetView:FilterFile(file)
    return true
end

function AssetView:AddFolder(folder)
    local tooltip
    local image = self.imageFolder

    local isProject = Project.IsDirProject(folder)
    if isProject then
        local projectInfoPath = Path.Join(folder, Project.PROJECT_FILE)
        if VFS.FileExists(projectInfoPath, VFS.RAW) then
            local projectInfo = VFS.Include(projectInfoPath, nil, VFS.RAW)
            local game, mapName = projectInfo.game, projectInfo.mapName
            local randomMapOptions = projectInfo.randomMapOptions
            local mutators = projectInfo.mutators or {}

            local mapStr = mapName
            if randomMapOptions ~= nil and
               randomMapOptions.new_map_x ~= nil and
               randomMapOptions.new_map_y ~= nil then
                mapStr = mapStr .. " (generated: " .. randomMapOptions.new_map_x ..
                         "x" .. randomMapOptions.new_map_y .. ")"
            end
            if #mutators ~= 0 then
                mapStr = mapStr .. "\nMutators: "
                for i, mutator in ipairs(mutators) do
                    mapStr = mapStr .. mutator
                    if i ~= #mutators then
                        mapStr = mapStr .. ", "
                    end
                end
            end

            tooltip = string.format("Game: %s %s\nMap: %s",
                game.name,
                game.version,
                mapStr
            )
        else
            Log.Warning("Missing \"" .. Project.PROJECT_FILE .. "\" for project: " .. tostring(folder))
        end

        local imgPath = Path.Join(folder, Project.SCREENSHOT_FILE)
        if VFS.FileExists(imgPath, VFS.RAW) then
            image = imgPath
        end
    end

    local item = self:AddItem(Path.ExtractFileName(folder), image, tooltip)
    item.path = folder
    item.isFolder = true
    item.isProject = isProject
end

function AssetView:AddFile(file)
    local ext = (Path.GetExt(file) or ""):lower()

    local texturePath
    if table.ifind(SB_IMG_EXTS, ext) then
        texturePath = ':clr' .. self.itemWidth .. ',' .. self.itemHeight .. ':' .. tostring(file)
        -- FIXME: why not just use the file directly? it works
        -- What is the performance/caching difference, if any?
        -- texturePath = file
    end

    local name = Path.ExtractFileName(file)
    local item = self:AddItem(name, texturePath, "")
    item.path = file
    item.isFile = true
end

function AssetView:PopulateItems()
    for _, file in pairs(self.files) do
        self:AddFile(file)
    end
end
