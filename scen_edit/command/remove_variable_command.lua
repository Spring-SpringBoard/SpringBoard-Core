RemoveVariableCommand = Command:extends{}
RemoveVariableCommand.className = "RemoveVariableCommand"

function RemoveVariableCommand:init(variableID)
    self.variableID = variableID
end

function RemoveVariableCommand:execute()
    error("RemoveVariableCommand is native-only; Lua execute should not run")
end

function RemoveVariableCommand:unexecute()
    error("RemoveVariableCommand is native-only; Lua unexecute should not run")
end
