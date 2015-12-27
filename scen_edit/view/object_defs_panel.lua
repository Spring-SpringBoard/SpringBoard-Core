SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "grid_view.lua")

ObjectDefsPanel = GridView:extends{}

function ObjectDefsPanel:init(tbl)
    local defaults = {
        iconX = 42,
        iconY = 42,
        multiSelect = true,
    }
    tbl = table.merge(tbl, defaults)
    GridView.init(self, tbl)

    self.unitTerrainId = 1
    self.unitTypesId = 1
    self.search = ""
    self.objectDefIcons = {}

    self.control:DisableRealign()
    self:PopulateItems()
    self.control:EnableRealign()
    self:Refresh()
end

function ObjectDefsPanel:Refresh()
    self.control:DisableRealign()
    self.control:DeselectAll()

    self:FilterItems()

    self.control:EnableRealign()

    if self.control.parent then
        self.control.parent:RequestRealign()
    else
        self.control:UpdateLayout()
        self.control:Invalidate()
    end
end

function ObjectDefsPanel:FilterItems()
    self.control:ClearChildren()
    for _, item in pairs(self.items) do
        local objectDefID = item.objectDefID
        if self:FilterObject(objectDefID) then
            self.control:AddChild(item)
        end
    end
end

function ObjectDefsPanel:SelectTerrainId(unitTerrainId)
    self.unitTerrainId = unitTerrainId
    self:Refresh()
end

function ObjectDefsPanel:SelectUnitTypesId(unitTypesId)
    self.unitTypesId = unitTypesId
    self:Refresh()
end

function ObjectDefsPanel:SetSearchString(search)
    self.search = search
    self:Refresh()
end

function ObjectDefsPanel:GetObjectDefID(index)
    return self.control.children[index].objectDefID
end

-- Custom unit/feature classes
UnitDefsPanel = ObjectDefsPanel:extends{}
function UnitDefsPanel:FilterObject(objectDefID)
    local unitDef = UnitDefs[objectDefID]
    local correctType = self.unitTypesId == 2 and unitDef.isBuilding or
            self.unitTypesId == 1 and not unitDef.isBuilding or
            self.unitTypesId == 3

    local correctTerrain = self.unitTerrainId == 1 and (not unitDef.canFly and
    not unitDef.floatOnWater and not unitDef.canSubmerge and unitDef.waterline == 0 and unitDef.minWaterDepth <= 0) or
            self.unitTerrainId == 2 and unitDef.canFly or
        self.unitTerrainId == 3 and (unitDef.canHover or unitDef.floatOnWater or unitDef.waterline > 0 or unitDef.minWaterDepth > 0) or
        self.unitTerrainId == 4
    return correctType and correctTerrain and unitDef.humanName:lower():find(self.search:lower():trim())
end

function UnitDefsPanel:PopulateItems()
    local items = {}
    for id, unitDef in pairs(UnitDefs) do
        table.insert(items, {unitDef.humanName:trim(), "#" .. unitDef.id, unitDef.humanName:trim(), unitDef.id})
    end
    table.sort(items, function(a, b) return a[1]:lower() < b[1]:lower() end)

    for i = 1, #items do
        local item = items[i]
        local ctrl = self:AddItem(item[1], item[2], item[3])
        ctrl.objectDefID = item[4]
    end
end

FeatureDefsPanel = ObjectDefsPanel:extends{}
function FeatureDefsPanel:init(tbl)
    ObjectDefsPanel.init(self, tbl)
    self.featureTypeId = 1
end
function FeatureDefsPanel:getUnitDefBuildPic(unitDef)
    unitImagePath = "unitpics/" .. unitDef.buildpicname
    local fileExists = VFS.FileExists(unitImagePath)
    if not fileExists then
        unitImagePath = "buildicons/_1to1_128x128/" .. unitDef.name .. ".png"
    end
    return unitImagePath
end
function FeatureDefsPanel:FilterObject(objectDefID)
    local featureDef = FeatureDefs[objectDefID]
    local correctType = false
    local correctUnit = true
    local unitDef = nil
    if self.featureTypeId == 3 then
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
        correctType = isWreck == (self.featureTypeId == 2)
        if correctType and isWreck then
            correctUnit = false
            local unitTerrainId = self.unitTerrainId
            local unitTypesId = self.unitTypesId
            local correctUnitType = false
            correctUnitType = unitTypesId == 2 and unitDef.isBuilding or
            unitTypesId == 1 and not unitDef.isBuilding or
            unitTypesId == 3

            correctTerrain = unitTerrainId == 1 and (not unitDef.canFly and
            not unitDef.floatOnWater and not unitDef.canSubmerge and unitDef.waterline == 0 and unitDef.minWaterDepth <= 0) or
            unitTerrainId == 2 and unitDef.canFly or
            unitTerrainId == 3 and (unitDef.canHover or unitDef.floatOnWater or unitDef.waterline > 0 or unitDef.minWaterDepth > 0) or
            unitTerrainId == 4
            if correctUnitType and correctTerrain then
                correctUnit = true
            end
        end
    end
    local name = featureDef.humanName or featureDef.tooltip or featureDef.name
    return correctType and correctUnit and name:lower():find(self.search:lower():trim())
end
function FeatureDefsPanel:PopulateItems()
    local featureTypeId = self.featureTypeId
    --TODO create a default picture for features
    local defaultPicture = nil
    for id, unitDef in pairs(UnitDefs) do
        defaultPicture = "unitpics/" .. unitDef.buildpicname
        break
    end
    local items = {}
    for id, featureDef in pairs(FeatureDefs) do
        if featureDef.tooltip and type(featureDef.tooltip) == "string" then
            local defName = featureDef.name:gsub("_heap", ""):gsub("_dead", "")
            unitDef = UnitDefNames[defName]
            if unitDef then
                isWreck = true
            end
        end
        --unitImagePath = "buildicons/_1to1_128x128/" .. "feature_" .. featureDef.name .. ".png"
        unitImagePath = "unitpics/featureplacer/" .. featureDef.name .. "_unit.png"
        local fileExists = VFS.FileExists(unitImagePath, VFS.MOD)
        if not fileExists then
            if unitDef then
                unitImagePath = self:getUnitDefBuildPic(unitDef)
            end
            if unitImagePath == nil or not VFS.FileExists(unitImagePath, VFS.MOD) then
                unitImagePath = ""
--                 unitImagePath = "%-" .. featureDef.id
            end
        end
        local name = featureDef.humanName or featureDef.tooltip or featureDef.name
        table.insert(items, {name:trim(), unitImagePath, name:trim(), featureDef.id})
    end
    table.sort(items, function(a, b) return a[1]:lower() < b[1]:lower() end)

    for i = 1, #items do
        local item = items[i]
        local ctrl = self:AddItem(item[1], item[2], item[3])
        ctrl.objectDefID = item[4]
        if item[2] == "" then
            SCEN_EDIT.delayGL(function()
                local tex = gl.CreateTexture(256, 256)
                gl.RenderToTexture(tex, function()
                    gl.TexRect(-1, -1, 1, 1)
                    gl.Texture(0, "-%" .. ctrl.objectDefID .. ":0")
                    featureBridge.DrawObject(ctrl.objectDefID, 0)
                    gl.Texture(0,false)
                end)
                ctrl.imgCtrl.file = tex
            end)
        end
    end
end
function FeatureDefsPanel:SelectFeatureTypesId(featureTypeId)
    self.featureTypeId = featureTypeId
    self:Refresh()
end