AddVariableCommand = UndoableCommand:extends{}
AddVariableCommand.className = "AddVariableCommand"

function AddVariableCommand:init(variable)
    self.className = "AddVariableCommand"
    self.variable = variable
end

function AddVariableCommand:execute()
    self.variableId = SCEN_EDIT.model.variableManager:addVariable(self.variable)
end

function AddVariableCommand:unexecute()
    SCEN_EDIT.model.variableManager:removeVariable(self.variableId)
end
