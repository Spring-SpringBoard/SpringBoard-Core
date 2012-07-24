WidgetAddTriggerCommand = AbstractCommand:extends{}

function WidgetAddTriggerCommand:init(id, value)
    self.className = "WidgetAddTriggerCommand"
    self.id = id
    self.value = value
end

function WidgetAddTriggerCommand:execute()
    self.newVar = self.value
    self.newVar.id = self.id
    SCEN_EDIT.model.triggerManager:addTrigger(self.newVar)
end
