UpdateTriggerCommand = Command:extends{}
UpdateTriggerCommand.className = "UpdateTriggerCommand"

function UpdateTriggerCommand:init(trigger)
    self.trigger = trigger
end

function UpdateTriggerCommand:execute()
    error("UpdateTriggerCommand is native-only; Lua execute should not run")
end

function UpdateTriggerCommand:unexecute()
    error("UpdateTriggerCommand is native-only; Lua unexecute should not run")
end
