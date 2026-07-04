SetWaterParamsCommand = NativeCommand:extends{}
SetWaterParamsCommand.className = "SetWaterParamsCommand"

function SetWaterParamsCommand:init(opts)
    self.opts = opts
    self.mergeCommand = "MergedCommand"
end
