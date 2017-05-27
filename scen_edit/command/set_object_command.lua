SetObjectCommand = Command:extends{}
SetObjectCommand.className = "SetObjectCommand"

function SetObjectCommand:execute(bridge)
    bridge.s11n:Set(self.params)
end

SetUnitCommand = SetObjectCommand:extends{}
SetUnitCommand.className = "SetUnitCommand"
function SetUnitCommand:init(params)
    self.className        = "SetUnitCommand"
    self.params           = params
end
function SetUnitCommand:execute()
    self:super("execute", unitBridge)
end

SetFeatureCommand = SetObjectCommand:extends{}
SetFeatureCommand.className = "SetFeatureCommand"
function SetFeatureCommand:init(params)
    self.className        = "SetFeatureCommand"
    self.params           = params
end
function SetFeatureCommand:execute()
    self:super("execute", featureBridge)
end