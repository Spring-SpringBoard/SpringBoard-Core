-- Executed and undone natively (Rust ObjectManager); see nativeCommandsOnly.
SetObjectParamCommand = Command:extends{}
SetObjectParamCommand.className = "SetObjectParamCommand"

function SetObjectParamCommand:init(objType, modelID, key, value)
    self.objType          = objType
    self.modelID          = modelID
    self.key              = key
    self.value            = value
end
