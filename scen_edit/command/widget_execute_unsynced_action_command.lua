WidgetExecuteUnsyncedActionCommand = AbstractCommand:extends{}

function WidgetExecuteUnsyncedActionCommand:init(typeName, resolvedInputs)
    self.className = "WidgetExecuteUnsyncedActionCommand"
    self.typeName = typeName
    self.resolvedInputs = resolvedInputs
end

function WidgetExecuteUnsyncedActionCommand:execute()
    local actionType = SB.metaModel.actionTypes[self.typeName]
    setfenv(actionType.executeUnsynced, getfenv())
    actionType.executeUnsynced(self.resolvedInputs)
end
