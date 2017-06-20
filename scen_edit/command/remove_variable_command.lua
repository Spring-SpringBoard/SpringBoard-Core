RemoveVariableCommand = Command:extends{}
RemoveVariableCommand.className = "RemoveVariableCommand"

function RemoveVariableCommand:init(variableID)
    self.className = "RemoveVariableCommand"
    self.variableID = variableID
end

function RemoveVariableCommand:execute()
    self.variable = SB.model.variableManager:getVariable(self.variableID)
    SB.model.variableManager:removeVariable(self.variableID)
end

function RemoveVariableCommand:unexecute()
    SB.model.variableManager:newVariable(self.variable)
end
