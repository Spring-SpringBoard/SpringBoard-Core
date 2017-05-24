AreaManagerListenerGadget = AreaManagerListener:extends{}

function AreaManagerListenerGadget:init()
end

function AreaManagerListenerGadget:onAreaAdded(areaId)
    local area = SB.model.areaManager:getArea(areaId)
    local cmd = WidgetAddAreaCommand(areaId, area)
    SB.commandManager:execute(cmd, true)
end

function AreaManagerListenerGadget:onAreaRemoved(areaId)
    local cmd = WidgetRemoveAreaCommand(areaId)
    SB.commandManager:execute(cmd, true)
end

function AreaManagerListenerGadget:onAreaChange(areaId, area)
    local cmd = WidgetUpdateAreaCommand(areaId, area)
    SB.commandManager:execute(cmd, true)
end
