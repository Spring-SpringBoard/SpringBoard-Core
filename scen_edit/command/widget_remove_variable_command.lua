WidgetRemoveVariableCommand = AbstractCommand:extends{}

function WidgetRemoveVariableCommand:init(id)
    self.className = "WidgetRemoveVariableCommand"
    self.id = id
end

function WidgetRemoveVariableCommand:execute()
    SB.model.variableManager:removeVariable(self.id)
end
