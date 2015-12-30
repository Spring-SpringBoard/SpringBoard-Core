SetObjectParamCommand = UndoableCommand:extends{}
SetObjectParamCommand.className = "SetObjectParamCommand"

function NoGetField(name)
    return name == "gravity" or name == "movectrl"
end

function SetObjectParamCommand:execute(bridge)
    local objectID = bridge.getObjectSpringID(self.objectModelID)
    if self.value == nil then
        local keys = {}
        for name, _ in pairs(self.key) do
            if not NoGetField(name) then
                table.insert(keys, name)
            end
        end
        self.old = bridge.s11n:Get(objectID, keys)
    else
        if not NoGetField(self.key) then
            self.old = bridge.s11n:Get(objectID, self.key)
        end
    end
    bridge.s11n:Set(objectID, self.key, self.value)
end

function SetObjectParamCommand:unexecute(bridge)
    if self.old == nil then
        return
    end
    local objectID = bridge.getObjectSpringID(self.objectModelID)
    if self.value == nil then
        bridge.s11n:Set(objectID, self.old)
    else
        bridge.s11n:Set(objectID, self.key, self.old)
    end
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