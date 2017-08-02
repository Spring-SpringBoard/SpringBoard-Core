SetGlobalLosCommand = Command:extends{}
SetGlobalLosCommand.className = "SetGlobalLosCommand"

function SetGlobalLosCommand:init(opts)
    self.className = "SetGlobalLosCommand"
    self.opts = opts
end

function SetGlobalLosCommand:execute()
    Log.Notice(("Set global LOS=%s for allyTeam:%d"):format(tostring(self.opts.value), self.opts.allyTeamID))
    Spring.SetGlobalLos(self.opts.allyTeamID, self.opts.value)
end
