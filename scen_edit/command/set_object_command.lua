SetObjectCommand = Command:extends{}
SetObjectCommand.className = "SetObjectCommand"

function SetObjectCommand:init(objType, params)
    self.className = "SetObjectCommand"
    self.objType   = objType
    self.params    = params
end

function SetObjectCommand:execute(bridge)
    local bridge = ObjectBridge.GetObjectBridge(self.objType)

    bridge.s11n:Set(self.params)
end
