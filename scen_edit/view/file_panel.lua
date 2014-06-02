--//=============================================================================
FilePanel = LayoutPanel:Inherit{
  -- so, this should be changed here as well
  -- (see unitdefsview.lua)
  classname = "imagelistview",

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
  extFilters = {'.sdz'},
  imageFile = SCEN_EDIT_IMG_DIR .. "file.png",
  dir = '',
  drawcontrolv2 = true,
  
  columns = 5,
}

local this = FilePanel
local inherited = this.inherited

--//=============================================================================


--//=============================================================================

function FilePanel:New(obj)
  if not obj.dir then
      obj.dir = FilePanel.lastDir
  end
  obj = inherited.New(self,obj)
  obj:SetDir(obj.dir)
  return obj
end

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

function FilePanel:_AddFile(name,imageFile)
  self:AddChild( LayoutPanel:New{
    width  = self.iconX+10,
    height = self.iconY+20,
    padding = {0,0,0,0},
    itemPadding = {0,0,0,0},
    itemMargin = {0,0,0,0},
    rows = 2,
    columns = 1,

    children = {
      Image:New{
        width  = self.iconX,
        height = self.iconY,
        passive = true,
        file = ':clr' .. self.iconX .. ',' .. self.iconY .. ':' .. imageFile,
      },
      Label:New{
        width = self.iconX+10,
        height = 20,
        align = 'center',
        autosize = false,
        caption = name,
      },
    },
  })
end


function FilePanel:ScanDir()
  local files = VFS.DirList(self.dir, "*", VFS.RAW_ONLY)
  local dirs  = VFS.SubDirs("", "*", VFS.RAW_ONLY)
  local imageFiles = {}
  for i=1,#files do
    local f = files[i]
    local ext = (f:GetExt() or ""):lower()
    if (table.ifind(self.extFilters,ext))then
      imageFiles[#imageFiles+1]=f
    end
  end

  self._dirsNum = #dirs
  self._dirList = dirs

  local n    = 1
  local items = self.items
  --FIXME: loading from complex paths is broken, uncomment this when they get fixed    
  --items[n] = '..'
  --n = n+1

  for i=1,#dirs do
    --FIXME: loading from complex paths is broken, uncomment this when they get fixed    
    --items[n],n=dirs[i],n+1
  end
  for i=1,#imageFiles do
    items[n],n=imageFiles[i],n+1
  end
  if (#items>n-1) then
    for i=n,#items do
      items[i] = nil
    end
  end

  self:DisableRealign()
    --// clear old
    for i=#self.children,1,-1 do
      self:RemoveChild(self.children[i])
    end

    --// add ".."
	--FIXME: loading from complex paths is broken, uncomment this when they get fixed    
    --self:_AddFile('..',self.imageFolderUp)

    --// add dirs at top
    for i=1,#dirs do
	  --FIXME: loading from complex paths is broken, uncomment this when they get fixed    
      --self:_AddFile(ExtractFileName(dirs[i]),self.imageFolder)
    end

    --// add files
    for i=1,#imageFiles do
      self:_AddFile(ExtractFileName(imageFiles[i]),self.imageFile)
    end
  self:EnableRealign()
end


function FilePanel:SetDir(directory)
  self:DeselectAll()
  self.dir = directory
  FilePanel.lastDir = self.dir
  self:ScanDir()

  if (self.parent) then
    self.parent:RequestRealign()
  else
    self:UpdateLayout()
    self:Invalidate()
  end
end


function FilePanel:GotoFile(filepath)
  local dir = ExtractDir(filepath)
  local file = ExtractFileName(filepath)
  self.dir = dir
  self:ScanDir()
  self:Select(file)

  if (self.parent) then
    if (self.parent.classname == "scrollpanel") then
      local x,y,w,h = self:GetItemXY(next(self.selectedItems))
      self.parent:SetScrollPos(x+w*0.5, y+h*0.5, true)
    end

    self.parent:RequestRealign()
  else
    self:UpdateLayout()
    self:Invalidate()
  end
end

--//=============================================================================

function FilePanel:Select(item)
  if (type(item)=="number") then
    self:SelectItem(item)
  else
    local items = self.items
    for i=1,#items do
      if (ExtractFileName(items[i])==item) then
        self:SelectItem(i)
        return
      end
    end
    self:SelectItem(1)
  end
end

--//=============================================================================

function FilePanel:DrawItemBkGnd(index)
  local cell = self._cells[index]
  local itemPadding = self.itemPadding

  if (self.selectedItems[index]) then
    self:DrawItemBackground(cell[1] - itemPadding[1],cell[2] - itemPadding[2],cell[3] + itemPadding[1] + itemPadding[3],cell[4] + itemPadding[2] + itemPadding[4],"selected")
  else
    self:DrawItemBackground(cell[1] - itemPadding[1],cell[2] - itemPadding[2],cell[3] + itemPadding[1] + itemPadding[3],cell[4] + itemPadding[2] + itemPadding[4],"normal")
  end
end

--//=============================================================================

function FilePanel:HitTest(x,y)
  local cx,cy = self:LocalToClient(x,y)
  local obj = inherited.HitTest(self,cx,cy)
  if (obj) then return obj end
  local itemIdx = self:GetItemIndexAt(cx,cy)
  return (itemIdx>=0) and self
end


function FilePanel:MouseDblClick(x,y)
  local cx,cy = self:LocalToClient(x,y)
  local itemIdx = self:GetItemIndexAt(cx,cy)

  if (itemIdx<0) then return end

  --FIXME: loading from complex paths is broken, change this when they get fixed    
  if false and (itemIdx==1) then
    self:SetDir(GetParentDir(self.dir))
    return self
  end

  --FIXME: loading from complex paths is broken, change this when they get fixed    
  if false and (itemIdx<=self._dirsNum+1) then
    self:SetDir(self._dirList[itemIdx-1])
    return self
  else
    self:CallListeners(self.OnDblClickItem, self.items[itemIdx], itemIdx)
    return self
  end
end

--//=============================================================================
