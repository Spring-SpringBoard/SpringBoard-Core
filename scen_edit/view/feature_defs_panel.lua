--//=============================================================================
FeatureDefsPanel = LayoutPanel:Inherit {
  --TODO: figure out how to use DrawItemBackground with correct class name, in this case "FeatureDefsPanel"
  classname = "imagelistview", 

  autosize = true,

  autoArrangeH = false,
  autoArrangeV = false,
  centerItems  = false,

  iconX     = 64,
  iconY     = 64,

  itemMargin    = {1, 1, 1, 1},

  selectable  = true,
  multiSelect = false,
  columns = 5,

  items = {},
  featureTypeId = 1,
  unitTerrainId = 1,
  unitTypesId = 1,
  teamId = 1,
}

local this = FeatureDefsPanel 
local inherited = this.inherited

--//=============================================================================

function FeatureDefsPanel:New(obj)
  obj = inherited.New(self, obj)
  obj:PopulateFeatureDefsPanel()
  return obj
end

--//=============================================================================
function FeatureDefsPanel:PopulateFeatureDefsPanel()
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
        local correctUnit = true
        local unitDef = nil
        if featureTypeId == 3 then
            correctType = true
        else
            local isWreck = false
            if featureDef.tooltip and type(featureDef.tooltip) == "string" then
                local defName = featureDef.name:gsub("_heap", ""):gsub("_dead", "")
                unitDef = UnitDefNames[defName]
                if unitDef then
                    isWreck = true
                end
            end
            correctType = isWreck == (featureTypeId == 1)
            if correctType and isWreck then
                correctUnit = false
                local unitTerrainId = self.unitTerrainId
                local unitTypesId = self.unitTypesId
                local correctUnitType = false
                correctUnitType = unitTypesId == 2 and unitDef.isBuilding or
                unitTypesId == 1 and not unitDef.isBuilding or
                unitTypesId == 3

                -- BEAUTIFUL, MARVEL AT IT'S GLORY FOR IT ILLUMINATES US ALL
                correctTerrain = unitTerrainId == 1 and (not unitDef.canFly and
                not unitDef.floater and not unitDef.canSubmerge and unitDef.waterline == 0 and unitDef.minWaterDepth <= 0) or
                unitTerrainId == 2 and unitDef.canFly or
                unitTerrainId == 3 and (unitDef.canHover or unitDef.floater or unitDef.waterline > 0 or unitDef.minWaterDepth > 0) or
                unitTerrainId == 4
                if correctUnitType and correctTerrain then
                    correctUnit = true
                end
            end
        end
        if correctType and correctUnit then
            --unitImagePath = "buildicons/_1to1_128x128/" .. "feature_" .. featureDef.name .. ".png"
            unitImagePath = "unitpics/featureplacer/" .. featureDef.name .. "_unit.png"
            local fileExists = VFS.FileExists(unitImagePath)
            if not fileExists then
                if unitDef ~= nil then
                    unitImagePath = SCEN_EDIT.getUnitDefBuildPic(unitDef)
                else
                    unitImagePath = ""
                end
            end
            local name = featureDef.humanName or featureDef.tooltip or featureDef.name
            self:AddImage(name, featureDef.id, unitImagePath)
        end
    end
    self.rows = #self.items / self.columns + 1
    self:SelectItem(0)
end

function FeatureDefsPanel:SelectTerrainId(unitTerrainId)
    self.unitTerrainId = unitTerrainId
    self:PopulateFeatureDefsPanel()
end

function FeatureDefsPanel:SelectFeatureTypesId(featureTypeId)
    self.featureTypeId = featureTypeId
    self:PopulateFeatureDefsPanel()
end

function FeatureDefsPanel:SelectTeamId(teamId)
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

function FeatureDefsPanel:AddImage(name, id, imagefile)
  table.insert(self.items, {name=name, id=id})
  self:AddChild(LayoutPanel:New{
    width  = self.iconX+10,
    height = self.iconY+20,
    padding = {0,0,0,0},
    itemPadding = {0,0,0,0},
    itemMargin = {0,0,0,0},
    rows = 2,
    columns = 1,

    children = {
      Image:New {
        width  = self.iconX,
        height = self.iconY,
        passive = true,
        file = ':clr' .. self.iconX .. ',' .. self.iconY .. ':' .. imagefile,
      },
      Label:New {
        width = self.iconX+10,
        height = 20,
        align = 'center',
        autosize = false,
        caption = name,
      },
    },
  })
end

function FeatureDefsPanel:Clear()
    self.children = {}
    self.items = {}
end

function FeatureDefsPanel:SelectTerrainId(unitTerrainId)
    self.unitTerrainId = unitTerrainId
    self:PopulateFeatureDefsPanel()
end

function FeatureDefsPanel:SelectUnitTypesId(unitTypesId)
    self.unitTypesId = unitTypesId
    self:PopulateFeatureDefsPanel()
end

--//=============================================================================

function FeatureDefsPanel:DrawItemBkGnd(index)
  local cell = self._cells[index]
  local itemPadding = self.itemPadding

  if (self.selectedItems[index]) then
    self:DrawItemBackground(cell[1] - itemPadding[1],cell[2] - itemPadding[2],cell[3] + itemPadding[1] + itemPadding[3],cell[4] + itemPadding[2] + itemPadding[4],"selected")
  else
    self:DrawItemBackground(cell[1] - itemPadding[1],cell[2] - itemPadding[2],cell[3] + itemPadding[1] + itemPadding[3],cell[4] + itemPadding[2] + itemPadding[4],"normal")
  end
end

--//=============================================================================

function FeatureDefsPanel:HitTest(x,y)
  local cx,cy = self:LocalToClient(x,y)
  local obj = inherited.HitTest(self,cx,cy)
  if (obj) then return obj end
  local itemIdx = self:GetItemIndexAt(cx,cy)
  return (itemIdx>=0) and self
end


function FeatureDefsPanel:MouseDblClick(x,y)
  local cx,cy = self:LocalToClient(x,y)
  local itemIdx = self:GetItemIndexAt(cx,cy)

  if (itemIdx<0) then return end

  self:CallListeners(self.OnDblClickItem, self.items[itemIdx], itemIdx)
  return self
end

--//=============================================================================
