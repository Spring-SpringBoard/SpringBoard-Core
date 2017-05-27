AreaManager = Observable:extends{}

function AreaManager:init()
    self:super('init')
    self.areaIdCount = 0
    self.areas = {}
end

function AreaManager:addArea(area, areaId)
    if areaId == nil then
        areaId = self.areaIdCount + 1
    end
    self.areaIdCount = areaId
    self.areas[areaId] = area
    self:callListeners("onAreaAdded", areaId)
    return areaId
end

function AreaManager:removeArea(areaId)
    if self.areas[areaId] ~= nil then
        self.areas[areaId] = nil
        self:callListeners("onAreaRemoved", areaId)
    end
end

function AreaManager:setArea(areaId, value)
    assert(self.areas[areaId])
    self.areas[areaId] = value
    self:callListeners("onAreaChange", areaId, value)
end

function AreaManager:getArea(areaId)
    return self.areas[areaId]
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
    self.areaIdCount = 0
    for _, kv in pairs(data) do
        id = kv.id
        area = kv.area
        self:addArea(area, id)
    end
end

function AreaManager:clear()
    for areaId, _ in pairs(self.areas) do
        self:removeArea(areaId)
    end
end
------------------------------------------------
-- Listener definition
------------------------------------------------
AreaManagerListener = LCS.class.abstract{}

function AreaManagerListener:onAreaAdded(areaId)
end

function AreaManagerListener:onAreaRemoved(areaId)
end

function AreaManagerListener:onAreaChange(areaId, area)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
