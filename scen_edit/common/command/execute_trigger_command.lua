ExecuteTriggerCommand = AbstractCommand:extends{}

function ExecuteTriggerCommand:init(triggerId)
    self.className = "ExecuteTriggerCommand"
    self.triggerId = triggerId
end

function ExecuteTriggerCommand:execute()
    SCEN_EDIT.rtModel:ExecuteTrigger(self.triggerId)
end
