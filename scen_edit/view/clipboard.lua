Clipboard = LCS.class{}

function Clipboard:init()
    self.units = {}
    self.features = {}
end

function Clipboard:Clear()
    self.units = {}
    self.features = {}
end

-- copy will remove the unit IDs 
function Clipboard:CopyUnits(unitIds)
    for _, unitId in pairs(unitIds) do
        local unit = SCEN_EDIT.model.unitManager:serializeUnit(unitId)
        unit.id = nil
        table.insert(self.units, unit)
    end
end

function Clipboard:CutUnitCommands(unitIds)
    self:CopyUnits(unitIds)
    local removeUnitCommands = {}
    for i = 1, #unitIds do
        local unitId = unitIds[i]
        local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
        local cmd = RemoveUnitCommand(modelUnitId)
        table.insert(removeUnitCommands, cmd)
    end
    return removeUnitCommands
end

function Clipboard:PasteUnitCommands(delta)
    local addUnitCommands = {}

    for _, unit in pairs(self.units) do
        local uc = SCEN_EDIT.deepcopy(unit)
        local x, y, z = uc.x, uc.y, uc.z
        uc.x = uc.x + delta.x
        uc.z = uc.z + delta.z
        local cmd = AddUnitCommand(uc)
        table.insert(addUnitCommands, cmd)
    end
    return addUnitCommands
end

function Clipboard:CopyFeatures(featureIds)
    for i = 1, #featureIds do
        local featureId = featureIds[i]
        local x, y, z = Spring.GetFeaturePosition(featureId)
        local featureTypeId = Spring.GetFeatureDefID(featureId)
        local featureTeamId = Spring.GetFeatureTeam(featureId)
        local dirX, dirY, dirZ = Spring.GetFeatureDirection(featureId)
        local angle = math.atan2(dirX, dirZ) * 180 / math.pi
        table.insert(self.features, {
            x = x,
            y = y,
            z = z,
            featureTypeId = featureTypeId,
            featureTeamId = featureTeamId,
            angle = angle,
        })
    end
end

function Clipboard:CutFeatureCommands(featureIds)
    self:CopyFeatures(featureIds)
    local removeFeatureCommands = {}
    for i = 1, #featureIds do
        local featureId = featureIds[i]
        local modelFeatureId = SCEN_EDIT.model.featureManager:getModelFeatureId(featureId)
        local cmd = RemoveFeatureCommand(modelFeatureId)
        table.insert(removeFeatureCommands, cmd)
    end
    return removeFeatureCommands
end

function Clipboard:PasteFeatureCommands(delta)
    local addFeatureCommands = {}
    for i = 1, #self.features do
        local feature = self.features[i]
        local x, y, z = feature.x, feature.y, feature.z
        local featureTypeId = feature.featureTypeId
        local featureTeamId = feature.featureTeamId
        local angle = feature.angle
        local cmd = AddFeatureCommand(featureTypeId, x + delta.x, y, z + delta.z, featureTeamId, angle)
        table.insert(addFeatureCommands, cmd)
    end
    return addFeatureCommands
end

function Clipboard:Cut(selection)
    self:Clear()
    local commands = {}
    if selection.units then
        local cmds = self:CutUnitCommands(selection.units)
        for _, cmd in pairs(cmds) do
            table.insert(commands, cmd)
        end
    end
    if selection.features then
        local cmds = self:CutFeatureCommands(selection.features)
        for _, cmd in pairs(cmds) do
            table.insert(commands, cmd)
        end
    end
    local cmd = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(cmd)
end

function Clipboard:Paste(coords)
    local commands = {}

    local avgX, avgZ = 0, 0
    for _, unit in pairs(self.units) do
        avgX = avgX + unit.x
        avgZ = avgZ + unit.z
    end
    for _, feature in pairs(self.features) do
        avgX = avgX + feature.x
        avgZ = avgZ + feature.z
    end
    avgX = avgX / (#self.features + #self.units)
    avgZ = avgZ / (#self.features + #self.units)
    local delta = { x = coords[1] - avgX, z = coords[3] - avgZ }

    if #self.units > 0 then
        local cmds = self:PasteUnitCommands(delta)
        for _, cmd in pairs(cmds) do
            table.insert(commands, cmd)
        end
    end
    if #self.features > 0 then
        local cmds = self:PasteFeatureCommands(delta)
        for _, cmd in pairs(cmds) do
            table.insert(commands, cmd)
        end
    end
    local cmd = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(cmd)
end

function Clipboard:Copy(selection)
    self:Clear()
    if selection.units then
        self:CopyUnits(selection.units)
    end
    if selection.features then
        self:CopyFeatures(selection.features)
    end
end