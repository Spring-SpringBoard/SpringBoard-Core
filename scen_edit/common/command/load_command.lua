LoadCommand = AbstractCommand:extends{}
LoadCommand.className = "LoadCommand"

function LoadCommand:init(modelString)
    self.className = "LoadCommand"
    self.modelString = modelString
end

function LoadCommand:execute()
    SCEN_EDIT.model:Load(self.modelString)
end
