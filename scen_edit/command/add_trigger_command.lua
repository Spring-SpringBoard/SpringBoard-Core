AddTriggerCommand = UndoableCommand:extends{}
AddTriggerCommand.className = "AddTriggerCommand"

function AddTriggerCommand:init(trigger)
    self.className = "AddTriggerCommand"
    self.trigger = trigger
end

function AddTriggerCommand:execute()
    self.triggerId = SCEN_EDIT.model.triggerManager:addTrigger(self.trigger)
end

function AddTriggerCommand:unexecute()
    SCEN_EDIT.model.triggerManager:removeTrigger(self.triggerId)
end
