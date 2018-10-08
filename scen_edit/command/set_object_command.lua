SetObjectCommand = Command:extends{}
SetObjectCommand.className = "SetObjectCommand"

function SetObjectCommand:init(objType, params)
    self.objType   = objType
    self.params    = params
end

function SetObjectCommand:execute()
    local bridge = ObjectBridge.GetObjectBridge(self.objType)

    bridge.s11n:Set(self.params)
end
