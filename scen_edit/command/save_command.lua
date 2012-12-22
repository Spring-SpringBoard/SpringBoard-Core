SaveCommand = AbstractCommand:extends{}
SaveCommand.className = "SaveCommand"

function SaveCommand:init(fileName)
    self.className = "SaveCommand"
    self.fileName = fileName
end

function SaveCommand:execute()
    SCEN_EDIT.model:Save(self.fileName)
end
