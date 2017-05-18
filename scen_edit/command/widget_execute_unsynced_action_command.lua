WidgetExecuteUnsyncedActionCommand = AbstractCommand:extends{}

function WidgetExecuteUnsyncedActionCommand:init(typeName, resolvedInputs)
    self.className = "WidgetExecuteUnsyncedActionCommand"
    self.typeName = typeName
    self.resolvedInputs = resolvedInputs
end

function WidgetExecuteUnsyncedActionCommand:execute()
    local actionType = SCEN_EDIT.metaModel.actionTypes[self.typeName]
    setfenv(actionType.executeUnsynced, getfenv())
    actionType.executeUnsynced(self.resolvedInputs)
end
