RemoveObjectCommand = Command:extends{}
RemoveObjectCommand.className = "RemoveObjectCommand"

function RemoveObjectCommand:init(objType, modelID)
    self.className        = "RemoveObjectCommand"
    self.objType          = objType
    self.modelID          = modelID
end

function RemoveObjectCommand:execute(bridge)
    local bridge = ObjectBridge.GetObjectBridge(self.objType)

    local objectID = bridge.getObjectSpringID(self.modelID)
    if objectID and bridge.ValidObject(objectID) then
        self.old = bridge.s11n:Get(objectID)
        bridge.s11n:Remove(objectID)
    end
end

function RemoveObjectCommand:unexecute(bridge)
    local bridge = ObjectBridge.GetObjectBridge(self.objType)

    if self.old then
        bridge.s11n:Add(self.old)
    end
end
