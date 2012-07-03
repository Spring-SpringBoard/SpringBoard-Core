--//=============================================================================
local Chili
if WG.Chili then
    Chili = WG.Chili

FeatureDefsView = Chili.LayoutPanel:Inherit {
  --TODO: figure out how to use DrawItemBackground with correct class name, in this case "FeatureDefsView"
  classname = "imagelistview", 

  autosize = true,

  autoArrangeH = false,
  autoArrangeV = false,
  centerItems  = false,

  iconX     = 32,
  iconY     = 32,

  itemMargin    = {1, 1, 1, 1},

  selectable  = true,
  multiSelect = false,
  columns = 5,

  items = {},
  featureTypeId = 1,
  teamId = 1,
}

local this = FeatureDefsView 
local inherited = this.inherited

--//=============================================================================

function FeatureDefsView:New(obj)
  obj = inherited.New(self, obj)
  obj:PopulateFeatureDefsView()
  return obj
end

--//=============================================================================
function FeatureDefsView:PopulateFeatureDefsView()
    self:Clear()
    local featureTypeId = self.featureTypeId
	--TODO create a default picture for features
	local defaultPicture = nil
	for id, unitDef in pairs(UnitDefs) do
		defaultPicture = "unitpics/" .. unitDef.buildpicname
		break
	end
    for id, featureDef in pairs(FeatureDefs) do
		local correctType = false
		if featureTypeId == 3 then
			correctType = true
		else
			local isWreck = false
			if featureDef.tooltip and type(featureDef.tooltip) == "string" then
				local nameLowercase = featureDef.name:lower()
				local tooltipLowercase = featureDef.tooltip:lower()
				if nameLowercase:find("heap") or nameLowercase:find("dead") or tooltipLowercase:find("wreck") or tooltipLowercase:find("heap") then
					isWreck = true
				end
			end
			correctType = isWreck == (featureTypeId == 1)
		end
        if correctType then
            --unitImagePath = "unitpics/" .. featureDef.buildpicname
			unitImagePath = defaultPicture
			local name = featureDef.humanName or featureDef.tooltip or featureDef.name
            self:AddImage(name, featureDef.id, unitImagePath)
        end
    end
    self.rows = #self.items / self.columns + 1
	self:SelectItem(0)
end

function FeatureDefsView:SelectTerrainId(unitTerrainId)
    self.unitTerrainId = unitTerrainId
    self:PopulateFeatureDefsView()
end

function FeatureDefsView:SelectFeatureTypesId(featureTypeId)
    self.featureTypeId = featureTypeId
    self:PopulateFeatureDefsView()
end

function FeatureDefsView:SelectTeamId(teamId)
    self.teamId = teamId
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

--//=============================================================================

function FeatureDefsView:AddImage(name, id, imagefile)
  table.insert(self.items, {name=name, id=id})
  self:AddChild(Chili.LayoutPanel:New{
    width  = self.iconX+10,
    height = self.iconY+20,
    padding = {0,0,0,0},
    itemPadding = {0,0,0,0},
    itemMargin = {0,0,0,0},
    rows = 2,
    columns = 1,

    children = {
      Chili.Image:New {
        width  = self.iconX,
        height = self.iconY,
        passive = true,
        file = ':clr' .. self.iconX .. ',' .. self.iconY .. ':' .. imagefile,
      },
      Chili.Label:New {
        width = self.iconX+10,
        height = 20,
        align = 'center',
        autosize = false,
        caption = name,
      },
    },
  })
end

function FeatureDefsView:Clear()
    self.children = {}
    self.items = {}
end

--//=============================================================================

function FeatureDefsView:DrawItemBkGnd(index)
  local cell = self._cells[index]
  local itemPadding = self.itemPadding

  if (self.selectedItems[index]) then
    self:DrawItemBackground(cell[1] - itemPadding[1],cell[2] - itemPadding[2],cell[3] + itemPadding[1] + itemPadding[3],cell[4] + itemPadding[2] + itemPadding[4],"selected")
  else
    self:DrawItemBackground(cell[1] - itemPadding[1],cell[2] - itemPadding[2],cell[3] + itemPadding[1] + itemPadding[3],cell[4] + itemPadding[2] + itemPadding[4],"normal")
  end
end

--//=============================================================================

function FeatureDefsView:HitTest(x,y)
  local cx,cy = self:LocalToClient(x,y)
  local obj = inherited.HitTest(self,cx,cy)
  if (obj) then return obj end
  local itemIdx = self:GetItemIndexAt(cx,cy)
  return (itemIdx>=0) and self
end


function FeatureDefsView:MouseDblClick(x,y)
  local cx,cy = self:LocalToClient(x,y)
  local itemIdx = self:GetItemIndexAt(cx,cy)

  if (itemIdx<0) then return end

  self:CallListeners(self.OnDblClickItem, self.items[itemIdx], itemIdx)
  return self
end

end

--//=============================================================================
