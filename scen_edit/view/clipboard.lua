Clipboard = LCS.class{}

function Clipboard:init()
    self:Clear()
end

function Clipboard:Clear()
    self.units      = {}
    self.features   = {}
    self.areas      = {}
end

-- copy will remove the unit IDs 
function Clipboard:CopyUnits(objectIDs)
    for _, objectID in pairs(objectIDs) do
        local object = unitBridge.s11n:Get(objectID)
        object.id = nil
        table.insert(self.units, object)
    end
end

function Clipboard:CutUnitCommands(objectIDs)
    self:CopyUnits(objectIDs)
    local cmds = {}
    for _, objectID in pairs(objectIDs) do
        local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(objectID)
        local cmd = RemoveUnitCommand(modelUnitId)
        table.insert(cmds, cmd)
    end
    return cmds
end

function Clipboard:PasteUnitCommands(delta)
    local cmds = {}
    for _, object in pairs(self.units) do
        local uc = SCEN_EDIT.deepcopy(object)
        uc.pos.x = uc.pos.x + delta.x
        uc.pos.z = uc.pos.z + delta.z
        local cmd = AddUnitCommand(uc)
        table.insert(cmds, cmd)
    end
    return cmds
end

function Clipboard:CopyFeatures(objectIDs)
    for _, objectID in pairs(objectIDs) do
        local object = featureBridge.s11n:Get(objectID)
        object.id = nil
        table.insert(self.features, object)
    end
end

function Clipboard:CutFeatureCommands(objectIDs)
    self:CopyFeatures(objectIDs)
    local cmds = {}
    for _, objectID in pairs(objectIDs) do
        local modelFeatureId = SCEN_EDIT.model.featureManager:getModelFeatureId(objectID)
        local cmd = RemoveFeatureCommand(modelFeatureId)
        table.insert(cmds, cmd)
    end
    return cmds
end

function Clipboard:PasteFeatureCommands(delta)
    local cmds = {}
    for _, object in pairs(self.features) do
        local uc = SCEN_EDIT.deepcopy(object)
        uc.pos.x = uc.pos.x + delta.x
        uc.pos.z = uc.pos.z + delta.z
        local cmd = AddFeatureCommand(uc)
        table.insert(cmds, cmd)
    end
    return cmds
end

function Clipboard:CopyAreas(objectIDs)
    for _, objectID in pairs(objectIDs) do
        table.insert(self.areas, SCEN_EDIT.model.areaManager:getArea(objectID))
    end
end

function Clipboard:CutAreaCommands(objectIDs)
    self:CopyAreas(objectIDs)
    local cmds = {}
    for _, objectID in pairs(objectIDs) do
        local cmd = RemoveAreaCommand(objectID)
        table.insert(cmds, cmd)
    end
    return cmds
end

function Clipboard:PasteAreaCommands(delta)
    local cmds = {}
    for i = 1, #self.areas do
        local area = self.areas[i]
        local x1, z1, x2, z2 = area[1] + delta.x, area[2] + delta.z, area[3] + delta.x, area[4] + delta.z
        local cmd = AddAreaCommand(x1, z1, x2, z2)
        table.insert(cmds, cmd)
    end
    return cmds
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
    if selection.areas then
        local cmds = self:CutAreaCommands(selection.areas)
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
    local count = #self.features + #self.units + #self.areas
    for _, unit in pairs(self.units) do
        avgX = avgX + unit.pos.x
        avgZ = avgZ + unit.pos.z
    end
    for _, feature in pairs(self.features) do
        avgX = avgX + feature.pos.x
        avgZ = avgZ + feature.pos.z
    end
    for _, area in pairs(self.areas) do
        avgX = avgX + (area[1] + area[3]) / 2
        avgZ = avgZ + (area[2] + area[4]) / 2
    end
    avgX = avgX / count
    avgZ = avgZ / count
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
    if #self.areas > 0 then
        local cmds = self:PasteAreaCommands(delta)
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
    if selection.areas then
        self:CopyAreas(selection.areas)
    end
end