RemoveTriggerCommand = Command:extends{}
RemoveTriggerCommand.className = "RemoveTriggerCommand"

function RemoveTriggerCommand:init(triggerId)
    self.className = "RemoveTriggerCommand"
    self.triggerId = triggerId
end

function RemoveTriggerCommand:execute()
    self.trigger = SB.model.triggerManager:getTrigger(self.triggerId)
    SB.model.triggerManager:removeTrigger(self.triggerId)
end

function RemoveTriggerCommand:unexecute()
    SB.model.triggerManager:addTrigger(self.trigger)
end
