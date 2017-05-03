WidgetExecuteUnsyncedActionCommand = AbstractCommand:extends{}

function WidgetExecuteUnsyncedActionCommand:init(actionTypeName, resolvedInputs)
    self.className = "WidgetExecuteUnsyncedActionCommand"
    self.actionTypeName = actionTypeName
    self.resolvedInputs = resolvedInputs
end

function WidgetExecuteUnsyncedActionCommand:execute()
    local actionType = SCEN_EDIT.metaModel.actionTypes[self.actionTypeName]
    setfenv(actionType.executeUnsynced, getfenv())
    actionType.executeUnsynced(self.resolvedInputs)
end
