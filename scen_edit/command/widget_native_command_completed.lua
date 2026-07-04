WidgetNativeCommandCompleted = Command:extends{}
WidgetNativeCommandCompleted.className = "WidgetNativeCommandCompleted"

function WidgetNativeCommandCompleted:init(cmdID)
    self.cmdID = cmdID
end

function WidgetNativeCommandCompleted:execute()
    SB.commandManager:completeNativeCommand(self.cmdID)
end
