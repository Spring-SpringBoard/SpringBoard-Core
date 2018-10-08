ExecuteTriggerCommand = Command:extends{}
ExecuteTriggerCommand.className = "ExecuteTriggerCommand"

function ExecuteTriggerCommand:init(triggerID)
    self.triggerID = triggerID
end

function ExecuteTriggerCommand:execute()
    SB.rtModel:ExecuteTrigger(self.triggerID)
end
