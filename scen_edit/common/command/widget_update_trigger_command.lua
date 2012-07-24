WidgetUpdateTriggerCommand = AbstractCommand:extends{}

function WidgetUpdateTriggerCommand:init(trigger)
    self.className = "WidgetUpdateTriggerCommand"
    self.trigger = trigger
end

function WidgetUpdateTriggerCommand:execute()
    SCEN_EDIT.model.triggerManager:setTrigger(self.trigger.id, self.trigger)
end
