RotateUnitState = AbstractState:extends{}

function RotateUnitState:init()
    self.unitGhostViews = {}
    self.newPosX = 0
    self.newPosZ = 0
end

function RotateUnitState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        self.newPosX = coords[1]
        self.newPosZ = coords[3]
        local selType, unitIds = SCEN_EDIT.view.selectionManager:GetSelection()
        self.unitGhostViews = {}
    
        for i = 1, #unitIds do
            local unitId = unitIds[i]
            local unitX, unitY, unitZ = Spring.GetUnitPosition(unitId)
            local dx = self.newPosX - unitX
            local dz = self.newPosZ - unitZ

            local len = math.sqrt(dx * dx + dz * dz)
            if len > 0 then
                local angle = { dx / len, dz / len}
                self.unitGhostViews[unitId] = math.atan2(angle[1], angle[2]) / math.pi * 180
            end
        end
    end
end

function RotateUnitState:MouseRelease(x, y, button)
    local commands = {}
    for unitId, angle in pairs(self.unitGhostViews) do
        local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
        local rotateCommand = RotateUnitCommand(modelUnitId, angle)
        table.insert(commands, rotateCommand)
    end
    local compoundCommand = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(compoundCommand)
    SCEN_EDIT.stateManager:SetState(DefaultState())
end

function RotateUnitState:DrawWorld()
    for unitId, angle in pairs(self.unitGhostViews) do
        gl.PushMatrix()
        gl.Color(0.1, 1, 0.1, 0.4)
        local unitType = Spring.GetUnitDefID(unitId)
        local unitTeamId = Spring.GetUnitTeam(unitId)
        local unitX, unitY, unitZ = Spring.GetUnitPosition(unitId)
        gl.Translate(unitX, unitY, unitZ)

        gl.Rotate(angle, 0, 1, 0)

        gl.UnitRaw(unitId, true)
--        gl.UnitShape(unitType, unitTeamId)
        gl.PopMatrix()
    end
end
