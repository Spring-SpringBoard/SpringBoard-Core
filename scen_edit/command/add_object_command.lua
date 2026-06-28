-- Executed and undone natively (Rust ObjectManager); see nativeCommandsOnly.
AddObjectCommand = Command:extends{}
AddObjectCommand.className = "AddObjectCommand"

function AddObjectCommand:init(objType, params)
    self.objType   = objType
    self.params    = params
end
