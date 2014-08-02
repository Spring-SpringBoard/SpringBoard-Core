LoadModelCommand = AbstractCommand:extends{}
LoadModelCommand.className = "LoadModelCommand"

function LoadModelCommand:init(modelString)
    self.className = "LoadModelCommand"
    self.modelString = modelString
end

function LoadModelCommand:execute()
    local mission = loadstring(self.modelString)()
    SCEN_EDIT.model:Load(mission)
end
