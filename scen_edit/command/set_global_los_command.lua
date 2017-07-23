SetGlobalLosCommand = Command:extends{}
SetGlobalLosCommand.className = "SetGlobalLosCommand"

function SetGlobalLosCommand:init(opts)
    self.className = "SetGlobalLosCommand"
    self.opts = opts
end

function SetGlobalLosCommand:execute()
    Spring.SetGlobalLos(self.opts.allyTeamID, self.opts.value)
end
