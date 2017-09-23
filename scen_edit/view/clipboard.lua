Clipboard = LCS.class{}

function Clipboard:init()
    self:Clear()
end

function Clipboard:Clear()
    self.copy = {}
end

-- COPY
function Clipboard:CopyObjects(objectIDs, bridge)
    local objects = bridge.s11n:Get(objectIDs)
    local objectCount = 0
    for _, object in pairs(objects) do
        -- Remove the object IDs
        object.id = nil
        object.__modelID = nil
        objectCount = objectCount + 1
    end
    return objects, objectCount
end

-- CUT
function Clipboard:GenerateCutObjectsCommands(objectIDs, bridge)
    local cmds = {}
    for _, objectID in pairs(objectIDs) do
        local objectModelID = bridge.getObjectModelID(objectID)
        local cmd = RemoveObjectCommand(bridge.name, objectModelID)
        table.insert(cmds, cmd)
    end
    return cmds
end

-- PASTE
function Clipboard:GeneratePasteObjectsCommands(delta, objects, bridge)
    local cmds = {}
    for _, object in pairs(objects) do
        local oc = SB.deepcopy(object)
        oc.pos.x = oc.pos.x + delta.x
        oc.pos.z = oc.pos.z + delta.z
        local cmd = AddObjectCommand(bridge.name, oc)
        table.insert(cmds, cmd)
    end
    return cmds
end

function Clipboard:Cut(objectGroups)
    self:Copy(objectGroups)
    local commands = {}
    for name, objectIDs in pairs(objectGroups) do
        local bridge = ObjectBridge.GetObjectBridge(name)
        local cmds = self:GenerateCutObjectsCommands(objectIDs, bridge)
        for _, cmd in ipairs(cmds) do
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
    -- local cp = Spring.GetClipboard()
    -- pcall(function()
    --     self.copy = loadstring(cp)()
    -- end)

    local avg = {x=0, y=0, z=0}
    local count = 0
    for name, objects in pairs(self.copy) do
        local bridge = ObjectBridge.GetObjectBridge(name)
        for _, object in pairs(objects) do
            local pos = object.pos
            avg.x = avg.x + pos.x
            avg.y = avg.y + pos.y
            avg.z = avg.z + pos.z
            count = count + 1
        end
    end

    avg.x = avg.x / count
    avg.y = avg.y / count
    avg.z = avg.z / count

    local delta = { x = coords[1] - avg.x, z = coords[3] - avg.z }

    local commands = {}
    for name, objects in pairs(self.copy) do
        local bridge = ObjectBridge.GetObjectBridge(name)
        local cmds = self:GeneratePasteObjectsCommands(delta, objects, bridge)
        for _, cmd in ipairs(cmds) do
            table.insert(commands, cmd)
        end
    end

    if #commands == 0 then
        return
    end
    local cmd = CompoundCommand(commands)
    SB.commandManager:execute(cmd)
end

function Clipboard:Copy(objectGroups)
    self:Clear()
    for name, objectIDs in pairs(objectGroups) do
        local bridge = ObjectBridge.GetObjectBridge(name)
        if bridge.s11n then
            local objects, count = self:CopyObjects(objectIDs, bridge)
            self.copy[name] = objects
        end
    end
    Spring.SetClipboard(table.show(self.copy))
end
