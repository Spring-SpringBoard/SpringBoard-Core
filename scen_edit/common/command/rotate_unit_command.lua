RotateUnitCommand = AbstractCommand:extends{}
SCEN_EDIT.SetClassName(RotateUnitCommand, "RotateUnitCommand")

function RotateUnitCommand:init(modelUnitId, angle)
    self.className = "RotateUnitCommand"
    self.modelUnitId = modelUnitId
    self.angle = angle
end

function RotateUnitCommand:execute()
    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)

    local dirX, dirY, dirZ = Spring.GetUnitDirection(unitId)
    self.oldAngle = math.atan2(dirX, dirZ) * 180 / math.pi
    Spring.SetUnitRotation(unitId, 0, -self.angle * math.pi / 180, 0)
end

function RotateUnitCommand:unexecute()
    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)
    Spring.SetUnitRotation(unitId, 0, -self.oldAngle * math.pi / 180, 0)
end
