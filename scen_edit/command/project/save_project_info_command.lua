SaveProjectInfoCommand = NativeCommand:extends{}
SaveProjectInfoCommand.className = "SaveProjectInfoCommand"

function SaveProjectInfoCommand:init(name, path, isNewProject)
    self.name = name
    self.path = path
    self.isNewProject = isNewProject
    self.project = SB.project:GetData()
end
