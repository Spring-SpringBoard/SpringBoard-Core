ExecuteTriggerCommand = Command:extends{}

function ExecuteTriggerCommand:init(triggerID)
    self.className = "ExecuteTriggerCommand"
    self.triggerID = triggerID
end

function ExecuteTriggerCommand:execute()
    SB.rtModel:ExecuteTrigger(self.triggerID)
end
