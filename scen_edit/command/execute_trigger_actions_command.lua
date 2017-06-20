ExecuteTriggerActionsCommand = Command:extends{}

function ExecuteTriggerActionsCommand:init(triggerID)
    self.className = "ExecuteTriggerActionsCommand"
    self.triggerID = triggerID
end

function ExecuteTriggerActionsCommand:execute()
    SB.rtModel:ExecuteTriggerActions(self.triggerID)
end
