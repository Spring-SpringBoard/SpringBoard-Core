RemoveTriggerCommand = NativeCommand:extends{}
RemoveTriggerCommand.className = "RemoveTriggerCommand"

function RemoveTriggerCommand:init(triggerID)
    self.triggerID = triggerID
end
