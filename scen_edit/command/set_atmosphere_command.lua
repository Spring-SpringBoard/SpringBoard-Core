SetAtmosphereCommand = Command:extends{}
SetAtmosphereCommand.className = "SetAtmosphereCommand"

function SetAtmosphereCommand:init(opts)
    self.opts = opts
    self._execute_unsynced = true
    self.mergeCommand = "MergedCommand"
end

function SetAtmosphereCommand:execute()
    if not self.old then
        self.old = {
            fogStart   = gl.GetAtmosphere("fogStart"),
            fogEnd     = gl.GetAtmosphere("fogEnd"),
            fogColor   = {gl.GetAtmosphere("fogColor")},
            skyColor   = {gl.GetAtmosphere("skyColor")},
        --     self:Set("skyDir",     gl.GetAtmosphere("skyDir"))
            sunColor   = {gl.GetAtmosphere("sunColor")},
            cloudColor = {gl.GetAtmosphere("cloudColor")}
        }
    end
    Spring.SetAtmosphere(self.opts)
end

function SetAtmosphereCommand:unexecute()
    Spring.SetAtmosphere(self.old)
end
