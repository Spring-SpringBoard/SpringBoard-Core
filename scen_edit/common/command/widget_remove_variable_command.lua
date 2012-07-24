WidgetRemoveVariableCommand = AbstractCommand:extends{}

function WidgetRemoveVariableCommand:init(id)
    self.className = "WidgetRemoveVariableCommand"
    self.id = id
end

function WidgetRemoveVariableCommand:execute()
    SCEN_EDIT.model.variableManager:removeVariable(self.id)
end
