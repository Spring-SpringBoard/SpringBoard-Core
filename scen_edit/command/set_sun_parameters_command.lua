SetSunParametersCommand = Command:extends{}
SetSunParametersCommand.className = "SetSunParametersCommand"

function SetSunParametersCommand:init(opts)
    self.className = "SetSunParametersCommand"
    self.opts = opts
    self._execute_unsynced = true
    self.mergeCommand = "MergedCommand"
end

function SetSunParametersCommand:execute()
    if not self.old then
        self.old = {
    --         params = {Spring.GetSunParameters()},
            params = {gl.GetSun()},
        }
    end
    Spring.SetSunDirection(self.opts.dirX, self.opts.dirY, self.opts.dirZ)
end

function SetSunParametersCommand:unexecute()
    Spring.SetSunDirection(self.old.params[1], self.old.params[2], self.old.params[3])
end
