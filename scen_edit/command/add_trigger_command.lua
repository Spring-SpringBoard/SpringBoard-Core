AddTriggerCommand = Command:extends{}
AddTriggerCommand.className = "AddTriggerCommand"

function AddTriggerCommand:init(trigger)
    self.trigger = trigger
end

function AddTriggerCommand:execute()
    error("AddTriggerCommand is native-only; Lua execute should not run")
end

function AddTriggerCommand:unexecute()
    error("AddTriggerCommand is native-only; Lua unexecute should not run")
end
