SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "grid_view.lua")

UnitDefsPanel = GridView:extends{}

function UnitDefsPanel:init(tbl)
    local defaults = {
        iconX = 42,
        iconY = 42,
        multiSelect = true,
    }
    tbl = table.merge(tbl, defaults)
    GridView.init(self, tbl)

    self.unitTerrainId = 1
    self.unitTypesId = 1

    self:PopulateUnitDefsPanel()
end

function UnitDefsPanel:PopulateUnitDefsPanel()
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

function UnitDefsPanel:PopulateItems()
    local unitTerrainId = self.unitTerrainId
    local unitTypesId = self.unitTypesId
    for id, unitDef in pairs(UnitDefs) do
        correctType = unitTypesId == 2 and unitDef.isBuilding or
            unitTypesId == 1 and not unitDef.isBuilding or
            unitTypesId == 3

        -- BEAUTIFUL, MARVEL AT IT'S GLORY FOR IT ILLUMINATES US ALL
        correctTerrain = unitTerrainId == 1 and (not unitDef.canFly and
        not unitDef.floatOnWater and not unitDef.canSubmerge and unitDef.waterline == 0 and unitDef.minWaterDepth <= 0) or
                unitTerrainId == 2 and unitDef.canFly or
            unitTerrainId == 3 and (unitDef.canHover or unitDef.floatOnWater or unitDef.waterline > 0 or unitDef.minWaterDepth > 0) or
            unitTerrainId == 4
        if correctType and correctTerrain then
            local item = self:AddItem(unitDef.humanName, "#" .. unitDef.id, unitDef.humanName)
            item.id = unitDef.id
        end
    end
    self.control:SelectItem(0)
end

function UnitDefsPanel:SelectTerrainId(unitTerrainId)
    self.unitTerrainId = unitTerrainId
    self:PopulateUnitDefsPanel()
end

function UnitDefsPanel:SelectUnitTypesId(unitTypesId)
    self.unitTypesId = unitTypesId
    self:PopulateUnitDefsPanel()
end

function UnitDefsPanel:GetObjectDefID(index)
    return self.control.children[index].id
end