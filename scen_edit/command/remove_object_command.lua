RemoveObjectCommand = AbstractCommand:extends{}
RemoveObjectCommand.className = "RemoveObjectCommand"

function RemoveObjectCommand:execute(bridge)
    local objectID = bridge.getObjectSpringID(self.objectModelID)
    if objectID and bridge.spValidObject(objectID) then
        self.old = bridge.s11n:Get(objectID)
        bridge.spDestroyObject(objectID, false, true)
    end
end
function RemoveObjectCommand:unexecute(bridge)
    if self.old then
        local objectID = bridge.s11n:Add(self.old)
        bridge.setObjectModelID(objectID, self.objectModelID)
    end
end

RemoveUnitCommand = RemoveObjectCommand:extends{}
RemoveUnitCommand.className = "RemoveUnitCommand"
function RemoveUnitCommand:init(objectModelID)
    self.className        = "RemoveUnitCommand"
    self.objectModelID    = objectModelID
end
function RemoveUnitCommand:execute()
    self:super("execute", unitBridge)
end
function RemoveUnitCommand:unexecute()
    self:super("unexecute", unitBridge)
end

RemoveFeatureCommand = RemoveObjectCommand:extends{}
RemoveFeatureCommand.className = "RemoveFeatureCommand"
function RemoveFeatureCommand:init(objectModelID)
    self.className        = "RemoveFeatureCommand"
    self.objectModelID    = objectModelID
end
function RemoveFeatureCommand:execute()
    self:super("execute", featureBridge)
end
function RemoveFeatureCommand:unexecute()
    self:super("unexecute", featureBridge)
end