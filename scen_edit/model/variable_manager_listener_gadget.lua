VariableManagerListenerGadget = VariableManagerListener:extends{}

function VariableManagerListenerGadget:init()
end

function VariableManagerListenerGadget:onVariableAdded(variableId)
    local variable = SCEN_EDIT.model.variableManager:getVariable(variableId)
    local cmd = WidgetAddVariableCommand(variableId, variable)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function VariableManagerListenerGadget:onVariableRemoved(variableId)
    local cmd = WidgetRemoveVariableCommand(variableId)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function VariableManagerListenerGadget:onVariableUpdated(variableId)
    local variable = SCEN_EDIT.model.variableManager:getVariable(variableId)
    local cmd = WidgetUpdateVariableCommand(variable)
    SCEN_EDIT.commandManager:execute(cmd, true)
end
