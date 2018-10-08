UpdateTriggerCommand = Command:extends{}
UpdateTriggerCommand.className = "UpdateTriggerCommand"

function UpdateTriggerCommand:init(trigger)
    self.trigger = trigger
end

function UpdateTriggerCommand:execute()
    self.old = SB.model.triggerManager:getTrigger(self.trigger.id)
    SB.model.triggerManager:setTrigger(self.trigger.id, self.trigger)
end

function UpdateTriggerCommand:unexecute()
    SB.model.triggerManager:setTrigger(self.trigger.id, self.old)
end
