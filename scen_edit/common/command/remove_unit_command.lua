RemoveUnitCommand = LCS.class{}
SCEN_EDIT.SetClassName(RemoveUnitCommand, "RemoveUnitCommand")

function RemoveUnitCommand:init(modelUnitId)
    self.className = "RemoveUnitCommand"
    self.modelUnitId = modelUnitId
end

function RemoveUnitCommand:execute()
    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)
    self.x, self.y, self.z = Spring.GetUnitPosition(unitId)
    self.unitTypeId = Spring.GetUnitDefID(unitId)
    self.unitTeamId = Spring.GetUnitTeam(unitId)
    local dirX, dirY, dirZ = Spring.GetUnitDirection(unitId)
    self.angle = math.atan2(dirX, dirZ) * 180 / math.pi
    Spring.DestroyUnit(unitId, false, true)
end

function RemoveUnitCommand:unexecute()
    local unitId = Spring.CreateUnit(self.unitTypeId, self.x, self.y, self.z, 0, self.unitTeamId)
    Spring.SetUnitRotation(unitId, 0, -self.angle * math.pi / 180, 0)
    SCEN_EDIT.model.unitManager:setUnitModelId(unitId, self.modelUnitId)
end
