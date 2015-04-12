LoadModelCommand = AbstractCommand:extends{}
LoadModelCommand.className = "LoadModelCommand"

function LoadModelCommand:init(modelString)
    self.className = "LoadModelCommand"
    self.modelString = modelString
end

function LoadModelCommand:execute()
    SCEN_EDIT.model:Clear()
    -- wait a bit
    GG.Delay.DelayCall(function()
        local mission = loadstring(self.modelString)()
        SCEN_EDIT.model:Load(mission)
    end, {}, 2)
end
