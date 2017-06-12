SetMapRenderingParamsCommand = Command:extends{}
SetMapRenderingParamsCommand.className = "SetMapRenderingParamsCommand"

function SetMapRenderingParamsCommand:init(opts)
    self.className = "SetMapRenderingParamsCommand"
    self.opts = opts
end

function SetMapRenderingParamsCommand:execute()
    local cmd = WidgetSetMapRenderingParamsCommand(self.opts)
    SB.commandManager:execute(cmd, true)
end

function SetMapRenderingParamsCommand:unexecute()
    -- FIXME: widget command undo isn't implemented correctly yet
end

WidgetSetMapRenderingParamsCommand = Command:extends{}
WidgetSetMapRenderingParamsCommand.className = "WidgetSetMapRenderingParamsCommand"

function WidgetSetMapRenderingParamsCommand:init(opts)
    self.opts = opts
end

function WidgetSetMapRenderingParamsCommand:execute()
    self.old = {
    }
    Spring.SetMapRenderingParams(self.opts)
end

function WidgetSetMapRenderingParamsCommand:unexecute()
    -- if #self.old.params >= 4 then
    --     Spring.SetSunParameters(self.old.params[1], self.old.params[2], self.old.params[3], self.old.params[4], self.old.params[5], self.old.params[6])
    -- else
    --     Spring.SetSunDirection(self.old.params[1], self.old.params[2], self.old.params[3])
    -- end
end
