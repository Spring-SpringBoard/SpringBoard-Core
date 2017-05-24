ExecuteTriggerActionsCommand = AbstractCommand:extends{}

function ExecuteTriggerActionsCommand:init(triggerId)
    self.className = "ExecuteTriggerActionsCommand"
    self.triggerId = triggerId
end

function ExecuteTriggerActionsCommand:execute()
    SB.rtModel:ExecuteTriggerActions(self.triggerId)
end
