WidgetAddVariableCommand = AbstractCommand:extends{}

function WidgetAddVariableCommand:init(id, value)
    self.className = "WidgetAddVariableCommand"
    self.id = id
    self.value = value
end

function WidgetAddVariableCommand:execute()
    self.newVar = self.value
    self.newVar.id = self.id
    SB.model.variableManager:addVariable(self.newVar)
end
