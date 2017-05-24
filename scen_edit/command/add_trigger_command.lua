AddTriggerCommand = UndoableCommand:extends{}
AddTriggerCommand.className = "AddTriggerCommand"

function AddTriggerCommand:init(trigger)
    self.className = "AddTriggerCommand"
    self.trigger = trigger
end

function AddTriggerCommand:execute()
    self.triggerId = SB.model.triggerManager:addTrigger(self.trigger)
end

function AddTriggerCommand:unexecute()
    SB.model.triggerManager:removeTrigger(self.triggerId)
end
