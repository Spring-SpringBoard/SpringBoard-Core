SetSunLightingCommand = NativeCommand:extends{}
SetSunLightingCommand.className = "SetSunLightingCommand"

function SetSunLightingCommand:init(opts)
    self.opts = opts
    self.mergeCommand = "MergedCommand"
end
