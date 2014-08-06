Clipboard = LCS.class{}

function Clipboard:init()
    self.units = {}
    self.features = {}
end

function Clipboard:Clear()
    self.units = {}
    self.features = {}
end

function Clipboard:CopyUnits(unitIds)
    self:Clear()
    for _, unitId in pairs(unitIds) do
        local unit = SCEN_EDIT.model.unitManager:serializeUnit(unitId)
        table.insert(self.units, unit)
    end
end

function Clipboard:CutUnits(unitIds)
    self:Clear()
    self:CopyUnits(unitIds)
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

function Clipboard:_PasteUnits(coords)
    local addUnitCommands = {}
    local avgX, avgZ = 0, 0
    for _, unit in pairs(self.units) do
        table.echo(unit)
        avgX = avgX + unit.x
        avgZ = avgZ + unit.z
    end
    avgX = avgX / #self.units
    avgZ = avgZ / #self.units
    local dx = coords[1] - avgX
    local dz = coords[3] - avgZ
    for _, unit in pairs(self.units) do
        local x, y, z = unit.x, unit.y, unit.z
        unit.x = unit.x + dx
        unit.z = unit.z + dz
        local cmd = AddUnitCommand(unit)
        table.insert(addUnitCommands, cmd)
    end
    local cmd = CompoundCommand(addUnitCommands)
    SCEN_EDIT.commandManager:execute(cmd)
end

function Clipboard:CopyFeatures(featureIds)
    self:Clear()
    for i = 1, #featureIds do
        local featureId = featureIds[i]
        local x, y, z = Spring.GetFeaturePosition(featureId)
        local featureTypeId = Spring.GetFeatureDefID(featureId)
        local featureTeamId = Spring.GetFeatureTeam(featureId)
        local dirX, dirY, dirZ = Spring.GetFeatureDirection(featureId)
        local angle = math.atan2(dirX, dirZ) * 180 / math.pi
        table.insert(self.features,
            {
                x = x,
                y = y,
                z = z,
                featureTypeId = featureTypeId,
                featureTeamId = featureTeamId,
                angle = angle,
            }
        )
    end
end

function Clipboard:CutFeatures(featureIds)
    self:Clear()
    self:CopyFeatures(featureIds)
    local removeFeatureCommands = {}
    for i = 1, #featureIds do
        local featureId = featureIds[i]
        local modelFeatureId = SCEN_EDIT.model.featureManager:getModelFeatureId(featureId)
        local cmd = RemoveFeatureCommand(modelFeatureId)
        table.insert(removeFeatureCommands, cmd)
    end
    local cmd = CompoundCommand(removeFeatureCommands)
    SCEN_EDIT.commandManager:execute(cmd)
end

function Clipboard:_PasteFeatures(coords)
    local addFeatureCommands = {}
    local avgX, avgZ = 0, 0
    for i = 1, #self.features do
        local feature = self.features[i]
        avgX = avgX + feature.x
        avgZ = avgZ + feature.z
    end
    avgX = avgX / #self.features
    avgZ = avgZ / #self.features
    local dx = coords[1] - avgX
    local dz = coords[3] - avgZ
    for i = 1, #self.features do
        local feature = self.features[i]
        local x, y, z = feature.x, feature.y, feature.z
        local featureTypeId = feature.featureTypeId
        local featureTeamId = feature.featureTeamId
        local angle = feature.angle
        local cmd = AddFeatureCommand(featureTypeId, x + dx, y, z + dz, featureTeamId, angle)
        table.insert(addFeatureCommands, cmd)
    end
    local cmd = CompoundCommand(addFeatureCommands)
    SCEN_EDIT.commandManager:execute(cmd)
end

function Clipboard:Paste(coords)
    if #self.units > 0 then
        self:_PasteUnits(coords)
    elseif #self.features > 0 then
        self:_PasteFeatures(coords)
    end
end
