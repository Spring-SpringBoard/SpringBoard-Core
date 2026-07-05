LoadProjectCommand = NativeCommand:extends{}
LoadProjectCommand.className = "LoadProjectCommand"

function LoadProjectCommand:init(path)
    self.path = path
end
