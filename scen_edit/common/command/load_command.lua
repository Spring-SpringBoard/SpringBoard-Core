LoadCommand = AbstractCommand:extends{}
LoadCommand.className = "LoadCommand"

function LoadCommand:init(modelString)
    self.className = "LoadCommand"
    self.modelString = modelString
end

function LoadCommand:execute()
    local mission = loadstring(self.modelString)()
    SCEN_EDIT.model:Load(mission)
end
