LoadModelCommand = Command:extends{}
LoadModelCommand.className = "LoadModelCommand"

function LoadModelCommand:init(modelString)
    self.className = "LoadModelCommand"
    self.modelString = modelString
end

function LoadModelCommand:execute()
    SB.model:Clear()
    GG.Delay.DelayCall(function()
        self:Load()
    end, {}, 8)
end

function LoadModelCommand:Load()
    Log.Notice("Loading model...")
    local mission = loadstring(self.modelString)()
    SB.model:Load(mission)
end
