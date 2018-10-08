AddVariableCommand = Command:extends{}
AddVariableCommand.className = "AddVariableCommand"

function AddVariableCommand:init(variable)
    self.variable = variable
end

function AddVariableCommand:execute()
    self.variableID = SB.model.variableManager:addVariable(self.variable)
end

function AddVariableCommand:unexecute()
    SB.model.variableManager:removeVariable(self.variableID)
end
