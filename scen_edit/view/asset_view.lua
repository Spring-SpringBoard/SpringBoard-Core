SB.Include(Path.Join(SB_VIEW_DIR, "grid_view.lua"))

AssetView = GridView:extends{}

function AssetView:init(tbl)
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

    self.layoutPanel.MouseDblClick = function(ctrl, x, y, button, mods)
        if button ~= 1 then
            return
        end
        local cx,cy = ctrl:LocalToClient(x,y)
        local itemIdx = ctrl:GetItemIndexAt(cx,cy)

        if itemIdx < 0 then return end

        if itemIdx == 1 and self.dir ~= "" then
            self:SetDir(Path.GetParentDir(self.dir))
            return ctrl
        end

        if itemIdx <= self._dirsNum + 1 then
            if self.dir ~= "" then
                itemIdx = itemIdx - 1
            end
            self:SetDir(self.dirs[itemIdx])
            return ctrl
        else
            ctrl:CallListeners(ctrl.OnDblClickItem, self.items[itemIdx], itemIdx)
            return ctrl
        end
    end
    if self.showPath then
        self.layoutPanel:SetPos(nil, 20)
        self.lblPath = Label:New {
            x = 5, y = 5,
            width = 100,
            height = 20,
            caption = "",
            parent = self.scrollPanel,
            font = {
                color = {0.7, 0.7, 0.7, 1.0},
            },
        }
        if self.rootDir then
            self.lblRootDir = Label:New {
                right = 5, y = 5,
                width = 100,
                height = 20,
                caption = "Root: " .. tostring(self.rootDir),
                parent = self.scrollPanel,
                font = {
                    color = {0.7, 0.7, 0.7, 1.0},
                },
            }
        end
    end
    self:SetDir(tbl.dir or '')
end

local image_exts = {'.jpg','.bmp','.png','.tga','.dds','.ico','.gif','.psd','.tif'} --'.psp'

function AssetView:SetDir(directory)
    self.layoutPanel:DeselectAll()
    self.dir = directory
    if self.lblPath then
        self.lblPath:SetCaption("Path: " .. self.dir)
    end
-- 	MaterialBrowser.lastDir = self.dir
    self:ScanDir()
end

function AssetView:ScanDir()
    self:ScanDirStarted()

    local files = self:_DirList()
    self.files = {}
    for _, file in pairs(files) do
        local ext = (file:GetExt() or ""):lower()
        if table.ifind(image_exts, ext) then
            if self:FilterFile(file) then
                table.insert(self.files, file)
            end
        end
    end
    self.dirs = self:_SubDirs()
    self._dirsNum = #self.dirs

    self:ScanDirFinished()

    self:StartMultiModify()
    self:ClearItems()

    --// add ".."
    if self.showDirs and self.dir ~= "" then
        self:AddItem('', self.imageFolderUp)
    end
    --// add dirs at top
    if self.showDirs then
        for _, dir in pairs(self.dirs) do
            local item = self:AddItem(Path.ExtractFileName(dir), self.imageFolder)
            item.path = dir
            item.isFolder = true
        end
    end
    self:PopulateItems()

    self:EndMultiModify()
end

function AssetView:SelectAsset(path)
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
        return VFS.DirList(self.dir, "*")
    end
end

function AssetView:_SubDirs()
    if self.rootDir then
        return SB.model.assetsManager:SubDirs(self.rootDir, self.dir, "*")
    else
        return VFS.SubDirs(self.dir, "*")
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

function AssetView:PopulateItems()
    for _, file in pairs(self.files) do
        local texturePath = ':clr' .. self.itemWidth .. ',' .. self.itemHeight .. ':' .. tostring(file)
        local name = Path.ExtractFileName(file)
        local item = self:AddItem(name, texturePath, "")
        item.path = file
        item.isFile = true
    end
end
