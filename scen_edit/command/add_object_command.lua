AddObjectCommand = NativeCommand:extends{}
AddObjectCommand.className = "AddObjectCommand"

function AddObjectCommand:init(objType, params)
    self.objType   = objType
    self.params    = params
end

function AddObjectCommand:execute()
    error("AddObjectCommand is native-only; Lua execute should not run")
end

function AddObjectCommand:unexecute()
    error("AddObjectCommand is native-only; Lua unexecute should not run")
end
