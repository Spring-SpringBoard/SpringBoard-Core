WidgetRemoveTriggerCommand = AbstractCommand:extends{}

function WidgetRemoveTriggerCommand:init(id)
    self.className = "WidgetRemoveTriggerCommand"
    self.id = id
end

function WidgetRemoveTriggerCommand:execute()
    SCEN_EDIT.model.triggerManager:removeTrigger(self.id)
end
