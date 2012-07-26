MoveUnitCommand = AbstractCommand:extends{}
MoveUnitCommand.className = "MoveUnitCommand"

function MoveUnitCommand:init(modelUnitId, newX, newY, newZ)
    self.className = "MoveUnitCommand"
    self.modelUnitId = modelUnitId
    self.newX = newX
    self.newY = newY
    self.newZ = newZ
end

function MoveUnitCommand:execute()
    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)
    local unitX, unitY, unitZ = Spring.GetUnitPosition(unitId)
    self.oldX = unitX
    self.oldY = unitY
    self.oldZ = unitZ

    Spring.SetUnitPosition(unitId, self.newX, self.newY, self.newZ)
    -- TODO: this is wrong and shouldn't be needed; but it seems that a glitch is causing units to create a move order to their previous position
    Spring.GiveOrderToUnit(unitId, CMD.STOP, {}, {})
    --SCEN_EDIT.model:MoveUnit(unitId, self.newX, self.newY, self.newZ)
end

function MoveUnitCommand:unexecute()
    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)
    Spring.SetUnitPosition(unitId, self.oldX, self.oldY, self.oldZ)
    -- TODO: this is wrong and shouldn't be needed; but it seems that a glitch is causing units to create a move order to their previous position
    Spring.GiveOrderToUnit(unitId, CMD.STOP, {}, {})
--    SCEN_EDIT.model:MoveUnit(unitId, self.oldX, self.oldY, self.oldZ)
end
