AddUnitCommand = UndoableCommand:extends{}
AddUnitCommand.className = "AddUnitCommand"

function AddUnitCommand:init(unitTypeId, x, y, z, unitTeamId, angle)
    self.className = "AddUnitCommand"
    self.x, self.y, self.z = x, y, z
    self.unitTypeId = unitTypeId
    self.unitTeamId = unitTeamId
    self.angle = angle
end

function AddUnitCommand:execute()
    local unitId = Spring.CreateUnit(self.unitTypeId, self.x, self.y, self.z, 0, self.unitTeamId)
    if unitId then
        local x = math.sin(math.rad(self.angle))
        local z = math.cos(math.rad(self.angle))
        Spring.SetUnitDirection(unitId, x, 0, z)
        if self.modelUnitId == nil then
            self.modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
        else
            SCEN_EDIT.model.unitManager:setUnitModelId(unitId, self.modelUnitId)
        end
    end
end

function AddUnitCommand:unexecute()
    if self.modelUnitId then
        local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)
        Spring.DestroyUnit(unitId, false, true)
    end
end
