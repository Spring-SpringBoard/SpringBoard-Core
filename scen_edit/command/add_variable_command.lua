AddVariableCommand = UndoableCommand:extends{}
AddVariableCommand.className = "AddVariableCommand"

function AddVariableCommand:init(variable)
    self.className = "AddVariableCommand"
    self.variable = variable
end

function AddVariableCommand:execute()
    self.variableId = SB.model.variableManager:addVariable(self.variable)
end

function AddVariableCommand:unexecute()
    SB.model.variableManager:removeVariable(self.variableId)
end
