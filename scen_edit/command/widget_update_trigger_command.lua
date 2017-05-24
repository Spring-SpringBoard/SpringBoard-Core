WidgetUpdateTriggerCommand = AbstractCommand:extends{}

function WidgetUpdateTriggerCommand:init(trigger)
    self.className = "WidgetUpdateTriggerCommand"
    self.trigger = trigger
end

function WidgetUpdateTriggerCommand:execute()
    SB.model.triggerManager:setTrigger(self.trigger.id, self.trigger)
end
