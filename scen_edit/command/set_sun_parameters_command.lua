SetSunParametersCommand = Command:extends{}
SetSunParametersCommand.className = "SetSunParametersCommand"

function SetSunParametersCommand:init(opts)
    self.className = "SetSunParametersCommand"
    self.opts = opts
    self._execute_unsynced = true
end

function SetSunParametersCommand:execute()
    self.old = {
--         params = {Spring.GetSunParameters()},
        params = {gl.GetSun()},
    }
    Spring.SetSunDirection(self.opts.dirX, self.opts.dirY, self.opts.dirZ)
end

function SetSunParametersCommand:unexecute()
    Spring.SetSunDirection(self.old.params[1], self.old.params[2], self.old.params[3])
end
