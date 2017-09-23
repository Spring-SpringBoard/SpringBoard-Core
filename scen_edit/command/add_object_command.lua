AddObjectCommand = Command:extends{}
AddObjectCommand.className = "AddObjectCommand"

function AddObjectCommand:init(objType, params)
    self.className = "AddObjectCommand"
    self.objType   = objType
    self.params    = params
end

function AddObjectCommand:execute(bridge)
    local bridge = ObjectBridge.GetObjectBridge(self.objType)

    local objectID = bridge.s11n:Add(self.params)
    self.params.objectID = objectID
    self.params.__modelID = bridge.getObjectModelID(objectID)
end

function AddObjectCommand:unexecute(bridge)
    local bridge = ObjectBridge.GetObjectBridge(self.objType)
    if not self.params.__modelID then
        Log.Warning("No modelID for un-add (remove).")
    end
    local objectID = bridge.getObjectSpringID(self.params.__modelID)
    if not objectID then
        Log.Warning("No objectID for un-add (remove) for modelID: .", self.params.__modelID)
    end
    bridge.s11n:Remove(objectID)
end
