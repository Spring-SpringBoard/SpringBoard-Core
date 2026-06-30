AddVariableCommand = Command:extends{}
AddVariableCommand.className = "AddVariableCommand"

function AddVariableCommand:init(variable)
    self.variable = variable
end

function AddVariableCommand:execute()
    error("AddVariableCommand is native-only; Lua execute should not run")
end

function AddVariableCommand:unexecute()
    error("AddVariableCommand is native-only; Lua unexecute should not run")
end
