SetSunParametersCommand = NativeCommand:extends{}
SetSunParametersCommand.className = "SetSunParametersCommand"

function SetSunParametersCommand:init(opts)
    self.opts = opts
    self.mergeCommand = "MergedCommand"
end
