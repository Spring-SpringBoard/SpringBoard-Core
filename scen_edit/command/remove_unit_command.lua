RemoveUnitCommand = UndoableCommand:extends{}
RemoveUnitCommand.className = "RemoveUnitCommand"

function RemoveUnitCommand:init(modelUnitId)
    self.className = "RemoveUnitCommand"
    self.modelUnitId = modelUnitId
end

function RemoveUnitCommand:execute()
    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)
    self.x, self.y, self.z = Spring.GetUnitPosition(unitId)
    self.unitTypeId = Spring.GetUnitDefID(unitId)
    self.unitTeamId = Spring.GetUnitTeam(unitId)
    self.oldDirX, self.oldDirY, self.oldDirZ = Spring.GetUnitDirection(unitId)
    Spring.DestroyUnit(unitId, false, true)
end

function RemoveUnitCommand:unexecute()
    local unitId = Spring.CreateUnit(self.unitTypeId, self.x, self.y, self.z, 0, self.unitTeamId)
    Spring.SetUnitDirection(unitId, self.oldDirX, self.oldDirY, self.oldDirZ)
    SCEN_EDIT.model.unitManager:setUnitModelId(unitId, self.modelUnitId)
end
