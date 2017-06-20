ViewAreaManagerListener = LCS.class{}

function ViewAreaManagerListener:init()
end

function ViewAreaManagerListener:onAreaAdded(areaID)
    SB.view.areaViews[areaID] = AreaView(areaID)
end

function ViewAreaManagerListener:onAreaRemoved(areaID)
    SB.view.areaViews[areaID] = nil
    if selected == areaID then
        selected = nil
    end
end

function ViewAreaManagerListener:onAreaChange(areaID, area)
end
