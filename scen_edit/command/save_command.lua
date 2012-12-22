SaveCommand = AbstractCommand:extends{}
SaveCommand.className = "SaveCommand"

function SaveCommand:init(modelString)
    self.className = "SaveCommand"
    self.modelString = modelString
end

function SaveCommand:execute()
    SCEN_EDIT.model:Save(self.modelString)
end
