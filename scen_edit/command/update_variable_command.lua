UpdateVariableCommand = UndoableCommand:extends{}
UpdateVariableCommand.className = "UpdateVariableCommand"

function UpdateVariableCommand:init(variable)
    self.className = "UpdateVariableCommand"
    self.variable = variable
end

function UpdateVariableCommand:execute()
    self.old = SB.model.variableManager:getVariable(self.variable.id)
    SB.model.variableManager:setVariable(self.variable.id, self.variable)
end

function UpdateVariableCommand:unexecute()
    SB.model.variableManager:setVariable(self.variable.id, self.old)
end
