RemoveObjectCommand = NativeCommand:extends{}
RemoveObjectCommand.className = "RemoveObjectCommand"

function RemoveObjectCommand:init(objType, modelID)
    self.objType          = objType
    self.modelID          = modelID
end

function RemoveObjectCommand:execute()
    error("RemoveObjectCommand is native-only; Lua execute should not run")
end

function RemoveObjectCommand:unexecute()
    error("RemoveObjectCommand is native-only; Lua unexecute should not run")
end
