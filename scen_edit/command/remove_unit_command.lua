RemoveUnitCommand = UndoableCommand:extends{}
RemoveUnitCommand.className = "RemoveUnitCommand"

function RemoveUnitCommand:init(modelUnitId)
    self.className = "RemoveUnitCommand"
    self.modelUnitId = modelUnitId
end

function RemoveUnitCommand:execute()
    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)
    self.oldUnit = SCEN_EDIT.model.unitManager:serializeUnit(unitId)
    Spring.DestroyUnit(unitId, false, true)
end

function RemoveUnitCommand:unexecute()
    SCEN_EDIT.model.unitManager:loadUnit(self.oldUnit)
end
