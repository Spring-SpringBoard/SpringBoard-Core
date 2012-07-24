UpdateVariableCommand = UndoableCommand:extends{}
UpdateVariableCommand.className = "UpdateVariableCommand"

function UpdateVariableCommand:init(variable)
    self.className = "UpdateVariableCommand"
    self.variable = variable
end

function UpdateVariableCommand:execute()
    self.old = SCEN_EDIT.model.variableManager:getVariable(self.variable.id)
    SCEN_EDIT.model.variableManager:setVariable(self.variable.id, self.variable)
end

function UpdateVariableCommand:unexecute()
    SCEN_EDIT.model.variableManager:setVariable(self.variable.id, self.old)
end
