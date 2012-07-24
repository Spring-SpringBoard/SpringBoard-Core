AreaManagerListenerGadget = AreaManagerListener:extends{}

function AreaManagerListenerGadget:init()
end

function AreaManagerListenerGadget:onAreaAdded(areaId)
    local area = SCEN_EDIT.model.areaManager:getArea(areaId)
    local cmd = WidgetAddAreaCommand(areaId, area)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function AreaManagerListenerGadget:onAreaRemoved(areaId)
    local cmd = WidgetRemoveAreaCommand(areaId)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function AreaManagerListenerGadget:onAreaChange(areaId, area)
    local cmd = WidgetUpdateAreaCommand(areaId, area)
    SCEN_EDIT.commandManager:execute(cmd, true)
end
