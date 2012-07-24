WidgetUpdateVariableCommand = AbstractCommand:extends{}

function WidgetUpdateVariableCommand:init(variable)
    self.className = "WidgetUpdateVariableCommand"
    self.variable = variable
end

function WidgetUpdateVariableCommand:execute()
    SCEN_EDIT.model.variableManager:setVariable(self.variable.id, self.variable)
end
