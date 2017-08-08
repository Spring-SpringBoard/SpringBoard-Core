SetWaterParamsCommand = Command:extends{}
SetWaterParamsCommand.className = "SetWaterParamsCommand"

function SetWaterParamsCommand:init(opts)
    self.className = "SetWaterParamsCommand"
    self.opts = opts
    self._execute_unsynced = true
    self.mergeCommand = "MergedCommand"
end

function SetWaterParamsCommand:execute()
    if gl and gl.GetWaterRendering and not self.old then
        self.old = {}
        for k, v in pairs(self.opts) do
            local retVal = {gl.GetWaterRendering(k)}
            if #retVal == 1 then
                retVal = retVal[1]
            end
            self.old[k] = retVal
        end
    end
    Spring.SetWaterParams(self.opts)

    Spring.SendCommands('water ' .. Spring.GetWaterMode())
end

function SetWaterParamsCommand:unexecute()
    if self.old then
        Spring.SetWaterParams(self.old)
        Spring.SendCommands('water ' .. Spring.GetWaterMode())
    end
end
