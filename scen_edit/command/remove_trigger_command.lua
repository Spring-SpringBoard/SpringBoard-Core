RemoveTriggerCommand = Command:extends{}
RemoveTriggerCommand.className = "RemoveTriggerCommand"

function RemoveTriggerCommand:init(triggerID)
    self.triggerID = triggerID
end

function RemoveTriggerCommand:execute()
    error("RemoveTriggerCommand is native-only; Lua execute should not run")
end

function RemoveTriggerCommand:unexecute()
    error("RemoveTriggerCommand is native-only; Lua unexecute should not run")
end
