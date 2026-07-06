SetObjectParamCommand = NativeCommand:extends{}
SetObjectParamCommand.className = "SetObjectParamCommand"

function SetObjectParamCommand:init(objType, modelID, key, value)
    self.objType          = objType
    self.modelID          = modelID
    self.key              = key
    self.value            = value
end

function SetObjectParamCommand:execute()
    error("SetObjectParamCommand is native-only; Lua execute should not run")
end

function SetObjectParamCommand:unexecute()
    error("SetObjectParamCommand is native-only; Lua unexecute should not run")
end
