-- Executed and undone natively (Rust ObjectManager); see nativeCommandsOnly.
RemoveObjectCommand = Command:extends{}
RemoveObjectCommand.className = "RemoveObjectCommand"

function RemoveObjectCommand:init(objType, modelID)
    self.objType          = objType
    self.modelID          = modelID
end
