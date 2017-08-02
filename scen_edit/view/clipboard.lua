Clipboard = LCS.class{}

function Clipboard:init()
    self:Clear()
end

function Clipboard:Clear()
    self.units          = {}
    self.unitCount      = 0
    self.features       = {}
    self.featureCount   = 0
    self.areas          = {}
    self.areaCount      = 0
end

-- COPY
function Clipboard:CopyObjects(objectIDs, bridge)
    local objects = bridge.s11n:Get(objectIDs)
    local objectCount = 0
    for _, object in pairs(objects) do
        -- Remove the object IDs
        object.id = nil
        objectCount = objectCount + 1
    end
    return objects, objectCount
end
function Clipboard:CopyUnits(objectIDs)
    self.units, self.unitCount = self:CopyObjects(objectIDs, unitBridge)
end
function Clipboard:CopyFeatures(objectIDs)
    self.features, self.featureCount = self:CopyObjects(objectIDs, featureBridge)
end

-- CUT
function Clipboard:CutObjectsCommands(objectIDs, bridge)
    local cmds = {}
    for _, objectID in pairs(objectIDs) do
        local objectModelID = bridge.getObjectModelID(objectID)
        local cmd = bridge.RemoveObjectCommand(objectModelID)
        table.insert(cmds, cmd)
    end
    return cmds
end
function Clipboard:CutUnitCommands(objectIDs)
    self:CopyUnits(objectIDs)
    return self:CutObjectsCommands(objectIDs, unitBridge)
end
function Clipboard:CutFeatureCommands(objectIDs)
    self:CopyFeatures(objectIDs)
    return self:CutObjectsCommands(objectIDs, featureBridge)
end

-- PASTE
function Clipboard:PasteObjectsCommands(delta, objects, bridge)
    local cmds = {}
    for _, object in pairs(objects) do
        local uc = SB.deepcopy(object)
        uc.pos.x = uc.pos.x + delta.x
        uc.pos.z = uc.pos.z + delta.z
        local cmd = bridge.AddObjectCommand(uc)
        table.insert(cmds, cmd)
    end
    return cmds
end
function Clipboard:PasteUnitCommands(delta)
    return self:PasteObjectsCommands(delta, self.units, unitBridge)
end
function Clipboard:PasteFeatureCommands(delta)
    return self:PasteObjectsCommands(delta, self.features, featureBridge)
end

function Clipboard:CopyAreas(objectIDs)
    for _, objectID in pairs(objectIDs) do
        table.insert(self.areas, SB.model.areaManager:getArea(objectID))
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
    if #selection.units > 0 then
        local cmds = self:CutUnitCommands(selection.units)
        for _, cmd in pairs(cmds) do
            table.insert(commands, cmd)
        end
    end
    if #selection.features > 0 then
        local cmds = self:CutFeatureCommands(selection.features)
        for _, cmd in pairs(cmds) do
            table.insert(commands, cmd)
        end
    end
    if #selection.areas > 0 then
        local cmds = self:CutAreaCommands(selection.areas)
        for _, cmd in pairs(cmds) do
            table.insert(commands, cmd)
        end
    end
    if #commands == 0 then
        return
    end
    local cmd = CompoundCommand(commands)
    SB.commandManager:execute(cmd)
end

function Clipboard:Paste(coords)
    local commands = {}

    local avgX, avgZ = 0, 0
    local count = self.featureCount + self.unitCount + #self.areas
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

    if self.unitCount > 0 then
        local cmds = self:PasteUnitCommands(delta)
        for _, cmd in pairs(cmds) do
            table.insert(commands, cmd)
        end
    end
    if self.featureCount > 0 then
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
    if #commands == 0 then
        return
    end
    local cmd = CompoundCommand(commands)
    SB.commandManager:execute(cmd)
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
    Spring.SetClipboard(table.show({
        units       = self.units,
        features    = self.features,
        areas       = self.areas,
    }))
end
