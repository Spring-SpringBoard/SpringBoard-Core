UnitManagerListenerGadget = UnitManagerListener:extends{}

function UnitManagerListenerGadget:init()
end

function UnitManagerListenerGadget:onUnitAdded(unitId, modelId)
    local cmd = WidgetAddUnitCommand(unitId, modelId)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function UnitManagerListenerGadget:onUnitRemoved(unitId, modelId)
    local cmd = WidgetRemoveUnitCommand(modelId)
    SCEN_EDIT.commandManager:execute(cmd, true)
end
