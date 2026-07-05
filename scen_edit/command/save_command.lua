SaveCommand = NativeCommand:extends{}
SaveCommand.className = "SaveCommand"

function SaveCommand:init(path, isNewProject)
    self.path = path
    self.isNewProject = isNewProject
end
