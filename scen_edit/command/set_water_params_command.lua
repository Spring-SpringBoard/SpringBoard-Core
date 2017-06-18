SetWaterParamsCommand = Command:extends{}
SetWaterParamsCommand.className = "SetWaterParamsCommand"

function SetWaterParamsCommand:init(opts)
    self.className = "SetWaterParamsCommand"
    self.opts = opts
    self._execute_unsynced = true
end

function SetWaterParamsCommand:execute()
    if gl and gl.GetWaterRendering and not self.oldValues then
        self.oldValues = {}
        for k, v in pairs(self.opts) do
            local retVal = {gl.GetWaterRendering(k)}
            if #retVal == 1 then
                retVal = retVal[1]
            end
            self.oldValues[k] = retVal
        end
    end
    Spring.SetWaterParams(self.opts)

    Spring.SendCommands('water ' .. Spring.GetWaterMode())
end

function SetWaterParamsCommand:unexecute()
    if self.oldValues then
        Spring.SetWaterParams(self.oldValues)
        Spring.SendCommands('water ' .. Spring.GetWaterMode())
    end
end
