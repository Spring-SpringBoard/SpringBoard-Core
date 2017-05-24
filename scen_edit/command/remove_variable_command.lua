RemoveVariableCommand = UndoableCommand:extends{}
RemoveVariableCommand.className = "RemoveVariableCommand"

function RemoveVariableCommand:init(variableId)
    self.className = "RemoveVariableCommand"
    self.variableId = variableId
end

function RemoveVariableCommand:execute()
    self.variable = SB.model.variableManager:getVariable(self.variableId)
    SB.model.variableManager:removeVariable(self.variableId)
end

function RemoveVariableCommand:unexecute()
    SB.model.variableManager:newVariable(self.variable)
end
