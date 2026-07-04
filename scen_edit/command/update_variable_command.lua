UpdateVariableCommand = NativeCommand:extends{}
UpdateVariableCommand.className = "UpdateVariableCommand"

function UpdateVariableCommand:init(variable)
    self.variable = variable
end
