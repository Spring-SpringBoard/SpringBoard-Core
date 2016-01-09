SetSunParametersCommand = UndoableCommand:extends{}
SetSunParametersCommand.className = "SetSunParametersCommand"

function SetSunParametersCommand:init(opts)
    self.className = "SetSunParametersCommand"
    self.opts = opts
end

function SetSunParametersCommand:execute()
    local cmd = WidgetSetSunParametersCommand(self.opts)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function SetSunParametersCommand:unexecute()
    -- FIXME: widget command undo isn't implemented correctly yet
end

WidgetSetSunParametersCommand = UndoableCommand:extends{}
WidgetSetSunParametersCommand.className = "WidgetSetSunParametersCommand"

function WidgetSetSunParametersCommand:init(opts)
    self.opts = opts
end

function WidgetSetSunParametersCommand:execute()
    self.old = {
--         manuallyControlled = Spring.IsSunManuallyControlled(),
--         params = {Spring.GetSunParameters()},
        params = {gl.GetSun()},
    }
    Spring.SetSunManualControl(true)
    if self.opts.startAngle then
        Spring.SetSunParameters(self.opts.dirX, self.opts.dirY, self.opts.dirZ,
            self.opts.distance, self.opts.startAngle, self.opts.orbitTime)
    else
        Spring.SetSunDirection(self.opts.dirX, self.opts.dirY, self.opts.dirZ)
    end
end

function WidgetSetSunParametersCommand:unexecute()
--     Spring.SetSunManualControl(self.old.manuallyControlled)
    if #self.old.params >= 4 then
        Spring.SetSunParameters(self.old.params[1], self.old.params[2], self.old.params[3], self.old.params[4], self.old.params[5], self.old.params[6])
    else
        Spring.SetSunDirection(self.old.params[1], self.old.params[2], self.old.params[3])
    end
end