WidgetRemoveTriggerCommand = AbstractCommand:extends{}

function WidgetRemoveTriggerCommand:init(id)
    self.className = "WidgetRemoveTriggerCommand"
    self.id = id
end

function WidgetRemoveTriggerCommand:execute()
    SB.model.triggerManager:removeTrigger(self.id)
end
