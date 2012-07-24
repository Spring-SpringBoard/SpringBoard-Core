Clipboard = LCS.class{}

function Clipboard:init()
    self.units = {}
end

function Clipboard:copyUnits(unitIds)
    self.units = {}
    for i = 1, #unitIds do
        local unitId = unitIds[i]
        local x, y, z = Spring.GetUnitPosition(unitId)
        local unitTypeId = Spring.GetUnitDefID(unitId)
        local unitTeamId = Spring.GetUnitTeam(unitId)
        local dirX, dirY, dirZ = Spring.GetUnitDirection(unitId)
        local angle = math.atan2(dirX, dirZ) * 180 / math.pi
        table.insert(self.units,
            {
                x = x,
                y = y,
                z = z,
                unitTypeId = unitTypeId,
                unitTeamId = unitTeamId,
                angle = angle,
            }
        )
    end
end

function Clipboard:cutUnits(unitIds)
    self:copyUnits(unitIds)
    local removeUnitCommands = {}
    for i = 1, #unitIds do
        local unitId = unitIds[i]
        local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
        local cmd = RemoveUnitCommand(modelUnitId)
        table.insert(removeUnitCommands, cmd)
    end
    local cmd = CompoundCommand(removeUnitCommands)
    SCEN_EDIT.commandManager:execute(cmd)
end

function Clipboard:pasteUnits(coords)
    local addUnitCommands = {}
    local avgX, avgZ = 0, 0
    for i = 1, #self.units do
        local unit = self.units[i]
        avgX = avgX + unit.x
        avgZ = avgZ + unit.z
    end
    avgX = avgX / #self.units
    avgZ = avgZ / #self.units
    local dx = coords[1] - avgX
    local dz = coords[3] - avgZ
    for i = 1, #self.units do
        local unit = self.units[i]
        local x, y, z = unit.x, unit.y, unit.z
        local unitTypeId = unit.unitTypeId
        local unitTeamId = unit.unitTeamId
        local angle = unit.angle
        local cmd = AddUnitCommand(unitTypeId, x + dx, y, z + dz, unitTeamId, angle)
        table.insert(addUnitCommands, cmd)
    end
    local cmd = CompoundCommand(addUnitCommands)
    SCEN_EDIT.commandManager:execute(cmd)
end
