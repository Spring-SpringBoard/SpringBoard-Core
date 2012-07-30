local Chili = WG.Chili

FileDialog = LCS.class{}

function FileDialog:init(dir)
--    self.dir = dir or ''
  --[[  self.panel = Chili.LayoutPanel:New {
        autosize = true,

        autoArrangeH = false,
        autoArrangeV = false,
        centerItems  = false,

        iconX     = 64,
        iconY     = 64,

        itemMargin    = {1, 1, 1, 1},

        selectable  = true,
        multiSelect = true,

        items = {},
    }-]]
    self.window = Chili.Window:New {
        x = 500,
        y = 500,
        width = 300,
        height = 300,
        parent = Chili.Screen0,
        caption = "File dialog",
        children = {
            Chili.ScrollPanel:New {
                width = "100%",
                height = "100%",
                children = {
                    Chili.ImageListView:New {
                        x = 10,
                        y = 10,
                        columns = 5,
                        itemMargin    = {1, 1, 1, 1},
                        itemPadding = {10, 10, 10, 10},
                    },
                },
        }
--            self.panel,
        },
    }
--    self:SetDir(self.dir)
end

local image_exts = {'.jpg','.bmp','.png','.tga','.dds','.ico','.gif','.psd','.tif'} --'.psp'

--//=============================================================================

local function GetParentDir(dir)
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


local function ExtractFileName(filepath)
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


local function ExtractDir(filepath)
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

--//=============================================================================

function FileDialog:_AddFile(name,imagefile)
  self.panel:AddChild(Chili.LayoutPanel:New{
    width  = self.panel.iconX+10,
    height = self.panel.iconY+20,
    padding = {0,0,0,0},
    itemPadding = {0,0,0,0},
    itemMargin = {0,0,0,0},
    rows = 2,
    columns = 1,

    children = {
      Chili.Image:New{
        width  = self.panel.iconX,
        height = self.panel.iconY,
        passive = true,
        file = ':clr' .. self.panel.iconX .. ',' .. self.panel.iconY .. ':' .. imagefile,
      },
      Chili.Label:New{
        width = self.panel.iconX+10,
        height = 20,
        align = 'center',
        autosize = false,
        caption = name,
      },
    },
  })
end


function FileDialog:ScanDir()
  local files = VFS.DirList(self.dir)
  local dirs  = VFS.SubDirs(self.dir)
  local imageFiles = {}
  for i = 1, #files do
    local f = files[i]
    local ext = (f:GetExt() or ""):lower()
    if (table.ifind(image_exts,ext))then
      imageFiles[#imageFiles+1]=f
    end
  end

  self._dirsNum = #dirs
  self._dirList = dirs

  local n    = 1
  local items = self.panel.items
  items[n] = '..'
  n = n+1

  for i=1,#dirs do
    items[n],n=dirs[i],n+1
  end
  for i=1,#imageFiles do
    items[n],n=imageFiles[i],n+1
  end
  if (#items>n-1) then
    for i=n,#items do
      items[i] = nil
    end
  end

  self.panel:DisableRealign()
    --// clear old
    for i=#self.panel.children,1,-1 do
      self.panel:RemoveChild(self.panel.children[i])
    end

    --// add ".."
    self:_AddFile('..',"LuaUI/widgets/chili/skins/Default/folder_up.png")

    --// add dirs at top
    for i=1,#dirs do
      self:_AddFile(ExtractFileName(dirs[i]),"LuaUI/widgets/chili/skins/Default/folder.png")
    end

    --// add files
    for i=1,#imageFiles do
      self:_AddFile(ExtractFileName(imageFiles[i]),imageFiles[i])
    end
  self.panel:EnableRealign()
end


function FileDialog:SetDir(directory)
  self.panel:DeselectAll()
  self.dir = directory
  self:ScanDir()

  if (self.panel.parent) then
    self.panel.parent:RequestRealign()
  else
    self.panel:UpdateLayout()
    self.panel:Invalidate()
  end
end


function FileDialog:GotoFile(filepath)
  local dir = ExtractDir(filepath)
  local file = ExtractFileName(filepath)
  self.dir = dir
  self:ScanDir()
  self:Select(file)

  if (self.panel.parent) then
    if (self.panel.parent.classname == "scrollpanel") then
      local x,y,w,h = self.panel.parent:GetItemXY(next(self.selectedItems))
      self.panel.parent:SetScrollPos(x+w*0.5, y+h*0.5, true)
    end

    self.panel.parent:RequestRealign()
  else
    self.panel:UpdateLayout()
    self.panel:Invalidate()
  end
end

--//=============================================================================

function FileDialog:Select(item)
  if (type(item)=="number") then
    self.panel:SelectItem(item)
  else
    local items = self.panel.items
    for i=1,#items do
      if (ExtractFileName(items[i])==item) then
        self.panel:SelectItem(i)
        return
      end
    end
    self.panel:SelectItem(1)
  end
end

--//=============================================================================

function FileDialog:DrawItemBkGnd(index)
  local cell = self._cells[index]
  local itemPadding = self.itemPadding

  if (self.selectedItems[index]) then
    self:DrawItemBackground(cell[1] - itemPadding[1],cell[2] - itemPadding[2],cell[3] + itemPadding[1] + itemPadding[3],cell[4] + itemPadding[2] + itemPadding[4],"selected")
  else
    self:DrawItemBackground(cell[1] - itemPadding[1],cell[2] - itemPadding[2],cell[3] + itemPadding[1] + itemPadding[3],cell[4] + itemPadding[2] + itemPadding[4],"normal")
  end
end

--//=============================================================================

function FileDialog:HitTest(x,y)
  local cx,cy = self:LocalToClient(x,y)
  local obj = inherited.HitTest(self,cx,cy)
  if (obj) then return obj end
  local itemIdx = self:GetItemIndexAt(cx,cy)
  return (itemIdx>=0) and self
end


function FileDialog:MouseDblClick(x,y)
  local cx,cy = self:LocalToClient(x,y)
  local itemIdx = self:GetItemIndexAt(cx,cy)

  if (itemIdx<0) then return end

  if (itemIdx==1) then
    self:SetDir(GetParentDir(self.dir))
    return self
  end

  if (itemIdx<=self._dirsNum+1) then
    self:SetDir(self._dirList[itemIdx-1])
    return self
  else
    self:CallListeners(self.OnDblClickItem, self.items[itemIdx], itemIdx)
    return self
  end
end

--//=============================================================================
