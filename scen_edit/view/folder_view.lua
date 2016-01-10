SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "grid_view.lua")

FolderView = GridView:extends{}

function FolderView:init(tbl)
    local defaults = {
        showDirs = true,
        imageFolderUp = nil,
        imageFolder = nil,
    }
    tbl = table.merge(defaults, tbl)
    GridView.init(self, tbl)
    
    self.showDirs = tbl.showDirs
    self.imageFolder = tbl.imageFolder or self._fakeControl.imageFolder
    self.imageFolderUp = tbl.imageFolderUp or self._fakeControl.imageFolderUp
    
    self.control.MouseDblClick = function(ctrl, x, y, button, mods)
        if button ~= 1 then
            return
        end
        local cx,cy = ctrl:LocalToClient(x,y)
        local itemIdx = ctrl:GetItemIndexAt(cx,cy)

        if (itemIdx<0) then return end

        if (itemIdx==1) then
            self:SetDir(self:GetParentDir(self.dir))
            return ctrl
        end

        if (itemIdx<=self._dirsNum+1) then
            self:SetDir(self.dirs[itemIdx-1])
            return ctrl
        else
            ctrl:CallListeners(ctrl.OnDblClickItem, ctrl.items[itemIdx], itemIdx)
            return ctrl
        end
    end
    self:SetDir(tbl.dir)
end

local image_exts = {'.jpg','.bmp','.png','.tga','.dds','.ico','.gif','.psd','.tif'} --'.psp'

function FolderView:GetParentDir(dir)
dir = dir:gsub("\\", "/")
local lastChar = dir:sub(-1)
if (lastChar == "/") then
    dir = dir:sub(1,-2)
end
local pos,b,e,match,init,n = 1,1,1,1,0,0
repeat
    pos,init,n = b,init+1,n+1
    b,init,match = dir:find("/",init,true)
until (not b)
if (n==1) then
    return ''
else
    return dir:sub(1,pos)
end
end

-- FIXME: Move this to a global file utility
function FolderView:ExtractFileName(filepath)
    filepath = filepath:gsub("\\", "/")
    local lastChar = filepath:sub(-1)
    if (lastChar == "/") then
        filepath = filepath:sub(1,-2)
    end
    local pos,b,e,match,init,n = 1,1,1,1,0,0
    repeat
        pos,init,n = b,init+1,n+1
        b,init,match = filepath:find("/",init,true)
    until (not b)
    if (n==1) then
        return filepath
    else
        return filepath:sub(pos+1)
    end
end

-- FIXME: Move this to a global file utility
function FolderView:ExtractDir(filepath)
    filepath = filepath:gsub("\\", "/")
    local lastChar = filepath:sub(-1)
    if (lastChar == "/") then
        filepath = filepath:sub(1,-2)
    end
    local pos,b,e,match,init,n = 1,1,1,1,0,0
    repeat
        pos,init,n = b,init+1,n+1
        b,init,match = filepath:find("/",init,true)
    until (not b)
    if (n==1) then
        return filepath
    else
        return filepath:sub(1,pos)
    end
end

function FolderView:SetDir(directory)
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

function FolderView:ScanDir()
    self:ScanDirStarted()
    
    local files = VFS.DirList(self.dir, "*")
    self.files = {}
    for _, file in pairs(files) do
        local ext = (file:GetExt() or ""):lower()
        if table.ifind(image_exts, ext) then
            if self:FilterFile(file) then
                table.insert(self.files, file)
            end
        end
    end
    
    self.dirs  = VFS.SubDirs(self.dir, "*")
    self._dirsNum = #self.dirs

    self:ScanDirFinished()
    
    self.control:DisableRealign()
    --// clear old
    self.control:ClearChildren()

    --// add ".."
    if self.showDirs then 
        self:AddItem('', self.imageFolderUp)
    end

    --// add dirs at top
    if self.showDirs then
        for _, dir in pairs(self.dirs) do
            self:AddItem(self:ExtractFileName(dir), self.imageFolder)
        end
    end
    self:PopulateItems()
    
    self.control:EnableRealign()
end

-- API. Override these functions
function FolderView:ScanDirStarted()
end

function FolderView:ScanDirFinished()
end

function FolderView:FilterFile(file)
end

function FolderView:PopulateItems()
end