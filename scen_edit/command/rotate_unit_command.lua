RotateUnitCommand = AbstractCommand:extends{}
RotateUnitCommand.className = "RotateUnitCommand"

function RotateUnitCommand:init(modelUnitId, angle)
    self.className = "RotateUnitCommand"
    self.modelUnitId = modelUnitId
    self.angle = angle
end

function RotateUnitCommand:execute()
    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)
    self.oldX, self.oldY, self.oldZ = Spring.GetUnitDirection(unitId)

    local x = math.sin(math.rad(self.angle))
    local z = math.cos(math.rad(self.angle))
    Spring.SetUnitDirection(unitId, x, 0, z)
end

function RotateUnitCommand:unexecute()
    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)
    Spring.SetUnitDirection(unitId, self.oldX, self.oldY, self.oldZ)
end
