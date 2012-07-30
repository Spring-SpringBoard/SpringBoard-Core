SelectionManager = LCS.class{}

function SelectionManager:init()
    self.selectedUnits = nil
    self.selectedFeatures = nil
    self.selectedAreas = nil
end

function SelectionManager:GetSelection()
    if self.selectedUnits then
        return "units", self.selectedUnits
    elseif self.selectedFeatures then
        return "features", self.selectedFeatures
    elseif self.selectedAreas then
        return "areas", self.selectedAreas
    end
end

function SelectionManager:ClearSelection()
    self.selectedUnits = nil
    Spring.SelectUnitArray({}, false)

    if self.selectedAreas then
        for _, areaId in pairs(self.selectedAreas) do
            SCEN_EDIT.view.areaViews[areaId].selected = false
        end
    end
    self.selectedAreas = nil

    self.selectedFeatures = nil
end

function SelectionManager:SelectUnits(unitIds)
    self:ClearSelection()
    Spring.SelectUnitArray(unitIds)
end

function SelectionManager:SelectFeatures(featureIds)
    self:ClearSelection()
end

function SelectionManager:SelectAreas(areaIds)
    self:ClearSelection()
end
