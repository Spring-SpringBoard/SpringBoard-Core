SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "grid_view.lua")

FeatureDefsPanel = GridView:extends{}

function FeatureDefsPanel:init(tbl)
    local defaults = {
        iconX = 42,
        iconY = 42,
        multiSelect = true,
    }
    tbl = table.merge(tbl, defaults)
    GridView.init(self, tbl)

    self.unitTerrainId = 1
    self.featureTypeId = 1
    self.unitTypesId = 1
end

function FeatureDefsPanel:PopulateFeatureDefsPanel()
    self.control:DisableRealign()
    self.control:ClearChildren()

    self:PopulateItems()

--     self:SelectItem(0)
    self.control:EnableRealign()

    if self.control.parent then
        self.control.parent:RequestRealign()
    else
        self.control:UpdateLayout()
        self.control:Invalidate()
    end
end

function FeatureDefsPanel:getUnitDefBuildPic(unitDef)
    unitImagePath = "unitpics/" .. unitDef.buildpicname
    local fileExists = VFS.FileExists(unitImagePath)
    if not fileExists then
        unitImagePath = "buildicons/_1to1_128x128/" .. unitDef.name .. ".png"
    end
    return unitImagePath
end

function FeatureDefsPanel:PopulateItems()
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
            correctType = isWreck == (featureTypeId == 2)
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
                not unitDef.floatOnWater and not unitDef.canSubmerge and unitDef.waterline == 0 and unitDef.minWaterDepth <= 0) or
                unitTerrainId == 2 and unitDef.canFly or
                unitTerrainId == 3 and (unitDef.canHover or unitDef.floatOnWater or unitDef.waterline > 0 or unitDef.minWaterDepth > 0) or
                unitTerrainId == 4
                if correctUnitType and correctTerrain then
                    correctUnit = true
                end
            end
        end
        if correctType and correctUnit then
            --unitImagePath = "buildicons/_1to1_128x128/" .. "feature_" .. featureDef.name .. ".png"
            unitImagePath = "unitpics/featureplacer/" .. featureDef.name .. "_unit.png"
            local fileExists = VFS.FileExists(unitImagePath, VFS.MOD)
            if not fileExists then
                if unitDef then
                    unitImagePath = self:getUnitDefBuildPic(unitDef)
                end
                if unitImagePath == nil or not VFS.FileExists(unitImagePath, VFS.MOD) then
                    unitImagePath = "%-" .. featureDef.id
                end
            end
            local name = featureDef.humanName or featureDef.tooltip or featureDef.name
            local item = self:AddItem(name, unitImagePath, name)
            item.id = featureDef.id
        end
    end
    self.control:SelectItem(0)
end

function FeatureDefsPanel:SelectTerrainId(unitTerrainId)
    self.unitTerrainId = unitTerrainId
    self:PopulateFeatureDefsPanel()
end

function FeatureDefsPanel:SelectFeatureTypesId(featureTypeId)
    self.featureTypeId = featureTypeId
    self:PopulateFeatureDefsPanel()
end

function FeatureDefsPanel:SelectUnitTypesId(unitTypesId)
    self.unitTypesId = unitTypesId
    self:PopulateFeatureDefsPanel()
end

function FeatureDefsPanel:GetObjectDefID(index)
    return self.control.children[index].id
end