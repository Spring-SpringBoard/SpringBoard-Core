TriggerManagerListenerWidget = TriggerManagerListener:extends{}

function TriggerManagerListenerWidget:init(triggerWindow)
    self.triggerWindow = triggerWindow
end

function TriggerManagerListenerWidget:onTriggerAdded(triggerId)
    self.triggerWindow:Populate()
end

function TriggerManagerListenerWidget:onTriggerRemoved(triggerId)
    self.triggerWindow:Populate()
end

function TriggerManagerListenerWidget:onTriggerUpdated(triggerId)
    self.triggerWindow:Populate()
end
