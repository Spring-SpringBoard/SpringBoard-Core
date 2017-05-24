TriggerManagerListenerGadget = TriggerManagerListener:extends{}

function TriggerManagerListenerGadget:init()
end

function TriggerManagerListenerGadget:onTriggerAdded(triggerId)
    local trigger = SB.model.triggerManager:getTrigger(triggerId)
    local cmd = WidgetAddTriggerCommand(triggerId, trigger)
    SB.commandManager:execute(cmd, true)
end

function TriggerManagerListenerGadget:onTriggerRemoved(triggerId)
    local cmd = WidgetRemoveTriggerCommand(triggerId)
    SB.commandManager:execute(cmd, true)
end

function TriggerManagerListenerGadget:onTriggerUpdated(triggerId)
    local trigger = SB.model.triggerManager:getTrigger(triggerId)
    local cmd = WidgetUpdateTriggerCommand(trigger)
    SB.commandManager:execute(cmd, true)
end
