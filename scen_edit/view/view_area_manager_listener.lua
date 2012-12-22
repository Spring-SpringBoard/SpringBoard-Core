ViewAreaManagerListener = LCS.class{}

function ViewAreaManagerListener:init()
end

function ViewAreaManagerListener:onAreaAdded(areaId)
    SCEN_EDIT.view.areaViews[areaId] = AreaView(areaId)
end

function ViewAreaManagerListener:onAreaRemoved(areaId)
    SCEN_EDIT.view.areaViews[areaId] = nil
    if selected == areaId then
        selected = nil
    end
end

function ViewAreaManagerListener:onAreaChange(areaId, area)
end
