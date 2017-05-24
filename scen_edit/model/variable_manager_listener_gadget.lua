VariableManagerListenerGadget = VariableManagerListener:extends{}

function VariableManagerListenerGadget:init()
end

function VariableManagerListenerGadget:onVariableAdded(variableId)
    local variable = SB.model.variableManager:getVariable(variableId)
    local cmd = WidgetAddVariableCommand(variableId, variable)
    SB.commandManager:execute(cmd, true)
end

function VariableManagerListenerGadget:onVariableRemoved(variableId)
    local cmd = WidgetRemoveVariableCommand(variableId)
    SB.commandManager:execute(cmd, true)
end

function VariableManagerListenerGadget:onVariableUpdated(variableId)
    local variable = SB.model.variableManager:getVariable(variableId)
    local cmd = WidgetUpdateVariableCommand(variable)
    SB.commandManager:execute(cmd, true)
end
