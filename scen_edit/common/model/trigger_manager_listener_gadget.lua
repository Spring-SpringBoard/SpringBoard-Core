TriggerManagerListenerGadget = TriggerManagerListener:extends{}

function TriggerManagerListenerGadget:init()
end

function TriggerManagerListenerGadget:onTriggerAdded(triggerId)
    Spring.Echo("added trigger")
    local trigger = SCEN_EDIT.model.triggerManager:getTrigger(triggerId)
    local cmd = WidgetAddTriggerCommand(triggerId, trigger)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function TriggerManagerListenerGadget:onTriggerRemoved(triggerId)
    local cmd = WidgetRemoveTriggerCommand(triggerId)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function TriggerManagerListenerGadget:onTriggerUpdated(triggerId)
    local trigger = SCEN_EDIT.model.triggerManager:getTrigger(triggerId)
    local cmd = WidgetUpdateTriggerCommand(trigger)
    SCEN_EDIT.commandManager:execute(cmd, true)
end
