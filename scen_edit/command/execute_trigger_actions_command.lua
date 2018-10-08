ExecuteTriggerActionsCommand = Command:extends{}
ExecuteTriggerActionsCommand.className = "ExecuteTriggerActionsCommand"

function ExecuteTriggerActionsCommand:init(triggerID)
    self.triggerID = triggerID
end

function ExecuteTriggerActionsCommand:execute()
    SB.rtModel:ExecuteTriggerActions(self.triggerID)
end
