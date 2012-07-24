AddUnitCommand = UndoableCommand:extends{}
SCEN_EDIT.SetClassName(AddUnitCommand, "AddUnitCommand")

function AddUnitCommand:init(unitTypeId, x, y, z, unitTeamId, angle)
    self.className = "AddUnitCommand"
    self.x, self.y, self.z = x, y, z
    self.unitTypeId = unitTypeId
    self.unitTeamId = unitTeamId
    self.angle = angle
end

function AddUnitCommand:execute()
    local unitId = Spring.CreateUnit(self.unitTypeId, self.x, self.y, self.z, 0, self.unitTeamId)
    Spring.SetUnitRotation(unitId, 0, -self.angle * math.pi / 180, 0)
    if self.modelUnitId == nil then
        self.modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
    else
        SCEN_EDIT.model.unitManager:setUnitModelId(unitId, self.modelUnitId)
    end
end

function AddUnitCommand:unexecute()
    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)
    Spring.DestroyUnit(unitId, false, true)
end
