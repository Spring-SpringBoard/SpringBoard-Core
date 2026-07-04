SetAtmosphereCommand = NativeCommand:extends{}
SetAtmosphereCommand.className = "SetAtmosphereCommand"

function SetAtmosphereCommand:init(opts)
    self.opts = opts
    self.mergeCommand = "MergedCommand"
end
