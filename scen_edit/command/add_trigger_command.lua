AddTriggerCommand = Command:extends{}
AddTriggerCommand.className = "AddTriggerCommand"

function AddTriggerCommand:init(trigger)
    self.trigger = trigger
end

function AddTriggerCommand:execute()
    self.triggerID = SB.model.triggerManager:addTrigger(self.trigger)
end

function AddTriggerCommand:unexecute()
    SB.model.triggerManager:removeTrigger(self.triggerID)
end
