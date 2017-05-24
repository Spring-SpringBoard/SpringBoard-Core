SB.Include(SB_VIEW_DIR .. "grid_view.lua")

AssetView = GridView:extends{}

function AssetView:init(tbl)
    local defaults = {
        showDirs = true,
        imageFolderUp = nil,
        imageFolder = nil,
    }
    tbl = Table.Merge(defaults, tbl)
    GridView.init(self, tbl)

    self.rootDir = tbl.rootDir
    self.showDirs = tbl.showDirs
    self.imageFolder = tbl.imageFolder or self._fakeControl.imageFolder
    self.imageFolderUp = tbl.imageFolderUp or self._fakeControl.imageFolderUp

    self.control.MouseDblClick = function(ctrl, x, y, button, mods)
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
            ctrl:CallListeners(ctrl.OnDblClickItem, ctrl.items[itemIdx], itemIdx)
            return ctrl
        end
    end
    self:SetDir(tbl.dir or '')
end

local image_exts = {'.jpg','.bmp','.png','.tga','.dds','.ico','.gif','.psd','.tif'} --'.psp'

function AssetView:SetDir(directory)
    self.control:DeselectAll()
    self.dir = directory
-- 	TextureBrowser.lastDir = self.dir
    self:ScanDir()

    if self.control.parent then
        self.control.parent:RequestRealign()
    else
        self.control:UpdateLayout()
        self.control:Invalidate()
    end
end

function AssetView:ScanDir()
    self:ScanDirStarted()

    local files = SB.model.assetsManager:DirList(self.rootDir, self.dir, "*")
    self.files = {}
    for _, file in pairs(files) do
        local ext = (file:GetExt() or ""):lower()
        if table.ifind(image_exts, ext) then
            if self:FilterFile(file) then
                table.insert(self.files, file)
            end
        end
    end

    self.dirs = SB.model.assetsManager:SubDirs(self.rootDir, self.dir, "*")
    self._dirsNum = #self.dirs

    self:ScanDirFinished()

    self.control:DisableRealign()
    --// clear old
    self.control:ClearChildren()

    --// add ".."
    if self.showDirs and self.dir ~= "" then
        self:AddItem('', self.imageFolderUp)
    end

    --// add dirs at top
    if self.showDirs then
        for _, dir in pairs(self.dirs) do
            local item = self:AddItem(Path.ExtractFileName(dir), self.imageFolder)
            item.dir = dir
        end
    end
    self:PopulateItems()

    self.control:EnableRealign()
end

-- API. Override these functions
function AssetView:ScanDirStarted()
end

function AssetView:ScanDirFinished()
end

function AssetView:FilterFile(file)
end

function AssetView:PopulateItems()
end
