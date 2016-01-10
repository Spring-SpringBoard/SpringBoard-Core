SetSunLightingCommand = UndoableCommand:extends{}
SetSunLightingCommand.className = "SetSunLightingCommand"

function SetSunLightingCommand:init(opts)
    self.className = "SetSunLightingCommand"
    self.opts = opts
end

function SetSunLightingCommand:execute()
    local cmd = WidgetSetSunLightingCommand(self.opts)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function SetSunLightingCommand:unexecute()
    -- FIXME: widget command undo isn't implemented correctly yet
end

WidgetSetSunLightingCommand = UndoableCommand:extends{}
WidgetSetSunLightingCommand.className = "WidgetSetSunLightingCommand"

function WidgetSetSunLightingCommand:init(opts)
    self.opts = opts
end

function WidgetSetSunLightingCommand:execute()
    self.old = {
        groundSunColor      = {gl.GetSun("diffuse")},
        groundAmbientColor  = {gl.GetSun("ambient")},
        groundSpecularColor = {gl.GetSun("specular")},
        unitDiffuseColor    = {gl.GetSun("diffuse", "unit")},
        unitAmbientColor    = {gl.GetSun("ambient", "unit")},
        unitSpecularColor   = {gl.GetSun("specular", "unit")},
    }
--     for _, v in pairs(self.old) do
--         v[4] = 1
--     end
    Spring.SetSunLighting(self.opts)
end

function WidgetSetSunLightingCommand:unexecute()
    Spring.SetSunLighting(self.old)
end