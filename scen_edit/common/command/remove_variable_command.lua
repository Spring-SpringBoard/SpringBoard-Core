RemoveVariableCommand = LCS.class{}
SCEN_EDIT.SetClassName(RemoveVariableCommand, "RemoveVariableCommand")

function RemoveVariableCommand:init(variableId)
    self.className = "RemoveVariableCommand"
    self.variableId = variableId
end

function RemoveVariableCommand:execute()
    self.variable = SCEN_EDIT.model.variableManager:getVariable(self.variableId)
    SCEN_EDIT.model.variableManager:removeVariable(self.variableId)
end

function RemoveVariableCommand:unexecute()
    SCEN_EDIT.model.variableManager:newVariable(self.variable)
end
