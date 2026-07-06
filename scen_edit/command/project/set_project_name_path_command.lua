SetProjectNamePathCommand = NativeCommand:extends{}
SetProjectNamePathCommand.className = "SetProjectNamePathCommand"

function SetProjectNamePathCommand:init(name, path)
    self.name = name
    self.path = path
end
