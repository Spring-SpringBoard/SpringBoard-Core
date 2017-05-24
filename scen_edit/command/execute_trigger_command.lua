ExecuteTriggerCommand = AbstractCommand:extends{}

function ExecuteTriggerCommand:init(triggerId)
    self.className = "ExecuteTriggerCommand"
    self.triggerId = triggerId
end

function ExecuteTriggerCommand:execute()
    SB.rtModel:ExecuteTrigger(self.triggerId)
end
