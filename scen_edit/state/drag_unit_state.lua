DragUnitState = AbstractState:extends{}
Spring.AssignMouseCursor('drag', 'drag', false)

function DragUnitState:init(unitId, startDiffX, startDiffZ)
    self.unitId = unitId
    self.dx = 0
    self.dz = 0
    self.startDiffX = startDiffX
    self.startDiffZ = startDiffZ
    self.unitGhostViews = {}
    SCEN_EDIT.SetMouseCursor("drag")
end

function DragUnitState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        if not Spring.ValidUnitID(self.unitId) or Spring.GetUnitIsDead(self.unitId) then
            SCEN_EDIT.stateManager:SetState(DefaultState())
            return false
        end
        local unitX, unitY, unitZ = Spring.GetUnitPosition(self.unitId)
        self.dx = coords[1] - unitX + self.startDiffX
        self.dz = coords[3] - unitZ + self.startDiffZ
        local selType, unitIds = SCEN_EDIT.view.selectionManager:GetSelection()
        self.unitGhostViews = {}
    
        for i = 1, #unitIds do
            local unitId = unitIds[i]
            local unitX, unitY, unitZ = Spring.GetUnitPosition(unitId)
            local y = Spring.GetGroundHeight(unitX + self.dx, unitZ + self.dz)
            local position = { unitX + self.dx, y, unitZ + self.dz}
            self.unitGhostViews[unitId] = position
        end
    end
end

function DragUnitState:MouseRelease(x, y, button)
    local commands = {}
    local selType, unitIds = SCEN_EDIT.view.selectionManager:GetSelection()
    for i = 1, #unitIds do
        local unitId = unitIds[i]
        local unitX, unitY, unitZ = Spring.GetUnitPosition(unitId)

        local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
        local moveCommand = MoveUnitCommand(modelUnitId, unitX + self.dx, unitY, unitZ + self.dz)
        table.insert(commands, moveCommand)
    end
    local compoundCommand = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(compoundCommand)

    SCEN_EDIT.stateManager:SetState(DefaultState())
end

function DragUnitState:DrawWorld()
    for unitId, pos in pairs(self.unitGhostViews) do
        gl.PushMatrix()
        local unitType = Spring.GetUnitDefID(unitId)
        local unitTeamId = Spring.GetUnitTeam(unitId)
        gl.Translate(pos[1], pos[2], pos[3])

        local dirX, dirY, dirZ = Spring.GetUnitDirection(unitId)
        local angleY = math.atan2(dirX, dirZ)
        
        if angleY ~= 0 then
            gl.Rotate(180 / math.pi * angleY, 0, 1, 0)
        end

        gl.Color(0.1, 1, 0.1, 0.8)
--        gl.UnitRaw(unitId, true)
        gl.UnitShape(unitType, unitTeamId)
        gl.PopMatrix()
    end
end
