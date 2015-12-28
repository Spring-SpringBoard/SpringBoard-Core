SetObjectParamCommand = UndoableCommand:extends{}
SetObjectParamCommand.className = "SetObjectParamCommand"

function SetObjectParamCommand:execute(bridge)
    local objectID = bridge.getSpringObjectID(self.objectModelID)
    self.old = bridge.s11n:Get(objectID, self.key)
    bridge.s11n:Set(objectID, self.key, self.value)
end

function SetObjectParamCommand:unexecute(bridge)
    local objectID = bridge.getSpringObjectID(self.objectModelID)
    bridge.s11n:Set(objectID, self.key, self.old)
end

SetUnitParamCommand = SetObjectParamCommand:extends{}
SetUnitParamCommand.className = "SetUnitParamCommand"
function SetUnitParamCommand:init(objectModelID, key, value)
    self.className        = "SetUnitParamCommand"
    self.objectModelID    = objectModelID
    self.key              = key
    self.value            = value
end
function SetUnitParamCommand:execute()
    self:super("execute", unitBridge)
end
function SetUnitParamCommand:unexecute()
    self:super("unexecute", unitBridge)
end

SetFeatureParamCommand = SetObjectParamCommand:extends{}
SetFeatureParamCommand.className = "SetFeatureParamCommand"
function SetFeatureParamCommand:init(objectModelID, key, value)
    self.className      = "SetFeatureParamCommand"
    self.objectModelID    = objectModelID
    self.key              = key
    self.value            = value
end
function SetFeatureParamCommand:execute()
    self:super("execute", featureBridge)
end
function SetFeatureParamCommand:unexecute()
    self:super("unexecute", featureBridge)
end