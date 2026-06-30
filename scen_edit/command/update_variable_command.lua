UpdateVariableCommand = Command:extends{}
UpdateVariableCommand.className = "UpdateVariableCommand"

function UpdateVariableCommand:init(variable)
    self.variable = variable
end

function UpdateVariableCommand:execute()
    error("UpdateVariableCommand is native-only; Lua execute should not run")
end

function UpdateVariableCommand:unexecute()
    error("UpdateVariableCommand is native-only; Lua unexecute should not run")
end
