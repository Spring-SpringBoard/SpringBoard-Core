WidgetNotifyModelCommand = Command:extends{}
WidgetNotifyModelCommand.className = "WidgetNotifyModelCommand"

function WidgetNotifyModelCommand:init(target, event, args)
    self.target = target
    self.event = event
    self.args = args or {}
end

function WidgetNotifyModelCommand:execute()
    local mgr = SB.model[self.target]
    if mgr and mgr.callListeners then
        mgr:callListeners(self.event, unpack(self.args or {}))
    end
end
