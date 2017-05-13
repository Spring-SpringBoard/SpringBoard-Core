SetWaterParamsCommand = UndoableCommand:extends{}
SetWaterParamsCommand.className = "SetWaterParamsCommand"

function SetWaterParamsCommand:init(opts)
    self.className = "SetWaterParamsCommand"
    self.opts = opts
end

function SetWaterParamsCommand:execute()
    local cmd = WidgetSetWaterParamsCommand(self.opts)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function SetWaterParamsCommand:unexecute()
    local cmd = WidgetUndoSetWaterParamsCommand()
    SCEN_EDIT.commandManager:execute(cmd, true)
end

WidgetSetWaterParamsCommand = AbstractCommand:extends{}
WidgetSetWaterParamsCommand.className = "WidgetSetWaterParamsCommand"

function WidgetSetWaterParamsCommand:init(opts)
    self.className = "WidgetSetWaterParamsCommand"
    self.opts = opts
end

local cmdStack = {}
function WidgetSetWaterParamsCommand:execute()
    if gl and gl.GetWaterRendering then
        self.oldValues = {}
        for k, v in pairs(self.opts) do
            local retVal = {gl.GetWaterRendering(k)}
            if #retVal == 1 then
                retVal = retVal[1]
            end
            self.oldValues[k] = retVal
        end
    end
    cmdStack[#cmdStack + 1] = self.oldValues
    Spring.SetWaterParams(self.opts)

    Spring.SendCommands('water ' .. Spring.GetWaterMode())
end

WidgetUndoSetWaterParamsCommand = AbstractCommand:extends{}
WidgetUndoSetWaterParamsCommand.className = "WidgetUndoSetWaterParamsCommand"

function WidgetUndoSetWaterParamsCommand:execute()
    local oldValues = cmdStack[#cmdStack]
    Spring.Echo(oldValues)
    cmdStack[#cmdStack] = nil
    if oldValues then
        Spring.SetWaterParams(oldValues)
    end
    Spring.SendCommands('water ' .. Spring.GetWaterMode())
end
