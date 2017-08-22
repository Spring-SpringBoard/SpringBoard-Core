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
    if self.modelID == nil then
        self.modelID = bridge.getObjectModelID(objectID)
    else
        bridge.setObjectModelID(objectID, self.modelID)
    end
end

function AddObjectCommand:unexecute(bridge)
    local bridge = ObjectBridge.GetObjectBridge(self.objType)

    if self.modelID then
        local objectID = bridge.getObjectSpringID(self.modelID)
        bridge.s11n:Remove(objectID)
    end
end
