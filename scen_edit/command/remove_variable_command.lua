RemoveVariableCommand = NativeCommand:extends{}
RemoveVariableCommand.className = "RemoveVariableCommand"

function RemoveVariableCommand:init(variableID)
    self.variableID = variableID
end
