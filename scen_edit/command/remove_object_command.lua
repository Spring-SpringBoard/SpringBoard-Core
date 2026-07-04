RemoveObjectCommand = NativeCommand:extends{}
RemoveObjectCommand.className = "RemoveObjectCommand"

function RemoveObjectCommand:init(objType, modelID)
    self.objType          = objType
    self.modelID          = modelID
end
