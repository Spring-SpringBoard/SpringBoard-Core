SetAtmosphereCommand = UndoableCommand:extends{}
SetAtmosphereCommand.className = "SetAtmosphereCommand"

function SetAtmosphereCommand:init(opts)
    self.className = "SetAtmosphereCommand"
    self.opts = opts
end

function SetAtmosphereCommand:execute()
    local cmd = WidgetSetAtmosphereCommand(self.opts)
    SB.commandManager:execute(cmd, true)
end

function SetAtmosphereCommand:unexecute()
    -- FIXME: widget command undo isn't implemented correctly yet
end

WidgetSetAtmosphereCommand = UndoableCommand:extends{}
WidgetSetAtmosphereCommand.className = "WidgetSetAtmosphereCommand"

function WidgetSetAtmosphereCommand:init(opts)
    self.opts = opts
end

function WidgetSetAtmosphereCommand:execute()
    self.old = {
        fogStart   = gl.GetAtmosphere("fogStart"),
        fogEnd     = gl.GetAtmosphere("fogEnd"),
        fogColor   = {gl.GetAtmosphere("fogColor")},
        skyColor   = {gl.GetAtmosphere("skyColor")},
    --     self:Set("skyDir",     gl.GetAtmosphere("skyDir"))
        sunColor   = {gl.GetAtmosphere("sunColor")},
        cloudColor = {gl.GetAtmosphere("cloudColor")}
    }
    Spring.SetAtmosphere(self.opts)
end

function WidgetSetAtmosphereCommand:unexecute()
    Spring.SetAtmosphere(self.old)
end