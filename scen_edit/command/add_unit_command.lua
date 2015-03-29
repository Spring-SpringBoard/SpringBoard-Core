AddUnitCommand = UndoableCommand:extends{}
AddUnitCommand.className = "AddUnitCommand"

function AddUnitCommand:init(unitTypeId, x, y, z, unitTeamId, angle)
    self.className = "AddUnitCommand"
    if type(unitTypeId) == "table" then
        -- all unit data is passed in a table
        self.unit = unitTypeId
    else
        self.x, self.y, self.z = x, y, z
        self.unitTypeId = unitTypeId
        self.unitTeamId = unitTeamId
        self.angle = angle
    end
end

function AddUnitCommand:execute()
    local unitId = nil

    if self.unit ~= nil then
        unitId = SCEN_EDIT.model.unitManager:loadUnit(self.unit)

    else
        unitId = Spring.CreateUnit(self.unitTypeId, self.x, self.y, self.z, 0, self.unitTeamId)
        if unitId then
            local x = math.sin(math.rad(self.angle))
            local z = math.cos(math.rad(self.angle))
            Spring.SetUnitDirection(unitId, x, 0, z)
        end
    end

    if self.modelUnitId == nil then
        self.modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
    else
        SCEN_EDIT.model.unitManager:setUnitModelId(unitId, self.modelUnitId)
    end
end

function AddUnitCommand:unexecute()
    if self.modelUnitId then
        local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.modelUnitId)
        Spring.DestroyUnit(unitId, false, true)
    end
end

function AddUnitCommand:display()
    local unitDefName = self.unitTypeId or self.unit.unitDefName
    return "Added unit: " .. tostring(unitDefName)
end