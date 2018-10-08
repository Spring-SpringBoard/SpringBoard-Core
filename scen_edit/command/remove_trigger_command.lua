RemoveTriggerCommand = Command:extends{}
RemoveTriggerCommand.className = "RemoveTriggerCommand"

function RemoveTriggerCommand:init(triggerID)
    self.triggerID = triggerID
end

function RemoveTriggerCommand:execute()
    self.trigger = SB.model.triggerManager:getTrigger(self.triggerID)
    SB.model.triggerManager:removeTrigger(self.triggerID)
end

function RemoveTriggerCommand:unexecute()
    SB.model.triggerManager:addTrigger(self.trigger)
end
