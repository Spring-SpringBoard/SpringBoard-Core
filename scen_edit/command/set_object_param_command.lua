SetObjectParamCommand = Command:extends{}
SetObjectParamCommand.className = "SetObjectParamCommand"

function SetObjectParamCommand:init(objType, modelID, key, value)
    self.className        = "SetObjectParamCommand"
    self.objType          = objType
    self.modelID          = modelID
    self.key              = key
    self.value            = value
end

local function NoGetField(name)
    return name == "gravity"
end

function SetObjectParamCommand:execute()
    local bridge = ObjectBridge.GetObjectBridge(self.objType)

    local objectID = bridge.getObjectSpringID(self.modelID)
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

function SetObjectParamCommand:unexecute()
    local bridge = ObjectBridge.GetObjectBridge(self.objType)

    if self.old == nil then
        return
    end
    local objectID = bridge.getObjectSpringID(self.modelID)
    if self.value == nil then
        bridge.s11n:Set(objectID, self.old)
    else
        bridge.s11n:Set(objectID, self.key, self.old)
    end
end
