AreaManager = Observable:extends{}

function AreaManager:init()
    self:super('init')
    self.areaIDCount = 0
    self.areas = {}
end

function AreaManager:addArea(area, areaID)
    if areaID == nil then
        areaID = self.areaIDCount + 1
    end
    self.areaIDCount = areaID
    self.areas[areaID] = area
    self:callListeners("onAreaAdded", areaID)
    return areaID
end

function AreaManager:removeArea(areaID)
    if self.areas[areaID] ~= nil then
        self.areas[areaID] = nil
        self:callListeners("onAreaRemoved", areaID)
    end
end

function AreaManager:setArea(areaID, value)
    assert(self.areas[areaID])
    self.areas[areaID] = value
    self:callListeners("onAreaChange", areaID, value)
end

function AreaManager:getArea(areaID)
    return self.areas[areaID]
end

function AreaManager:getAllAreas()
    local areas = {}
    for id, _ in pairs(self.areas) do
        table.insert(areas, id)
    end
    return areas
end

function AreaManager:serialize()
    local retVal = {}
    for id, area in pairs(self.areas) do
        table.insert(retVal, {
            area = area,
            id = id,
        })
    end
    return retVal
end

function AreaManager:load(data)
    self.areaIDCount = 0
    for _, kv in pairs(data) do
        id = kv.id
        area = kv.area
        self:addArea(area, id)
    end
end

function AreaManager:clear()
    for areaID, _ in pairs(self.areas) do
        self:removeArea(areaID)
    end
end
------------------------------------------------
-- Listener definition
------------------------------------------------
AreaManagerListener = LCS.class.abstract{}

function AreaManagerListener:onAreaAdded(areaID)
end

function AreaManagerListener:onAreaRemoved(areaID)
end

function AreaManagerListener:onAreaChange(areaID, area)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
