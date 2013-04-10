UnitManager = Observable:extends{}

function UnitManager:init(widget)
    self:super('init')
    self.s2mUnitIdMapping = {}
    self.m2sUnitIdMapping = {}
    self.unitIdCounter = 0
    self.widget = widget
end

function UnitManager:populate()
    if not self.widget then
        local allUnits = Spring.GetAllUnits()
        for i = 1, #allUnits do
            local unitId = allUnits[i]
            self:addUnit(unitId)
        end
    end
end

function UnitManager:addUnit(unitId, modelId)
    if self.s2mUnitIdMapping[unitId] then
        return
    end
    if modelId ~= nil then
        if self.unitIdCounter < modelId then
            self.unitIdCounter = modelId
        end
    else
        self.unitIdCounter = self.unitIdCounter + 1
        modelId = self.unitIdCounter
    end
    if not self.s2mUnitIdMapping[unitId] then
        self.s2mUnitIdMapping[unitId] = modelId 
    end
    if not self.m2sUnitIdMapping[modelId] then
        self.m2sUnitIdMapping[modelId] = unitId
    end

    self:callListeners("onUnitAdded", unitId, modelId)
    return modelId 
end

function UnitManager:removeUnit(unitId)
    if unitId == nil then
        return
    end
    local modelId = self.s2mUnitIdMapping[unitId]
    if self.s2mUnitIdMapping[unitId] then
        self.m2sUnitIdMapping[modelId] = nil
    end
    self.s2mUnitIdMapping[unitId] = nil

    self:callListeners("onUnitRemoved", unitId, modelId)
end

function UnitManager:removeUnitByModelId(modelId)
    local springId = self.m2sUnitIdMapping[modelId]
    self:removeUnit(springId)
end

function UnitManager:getSpringUnitId(modelUnitId)
    return self.m2sUnitIdMapping[modelUnitId]
end

function UnitManager:getModelUnitId(springUnitId)
    return self.s2mUnitIdMapping[springUnitId]
end

function UnitManager:setUnitModelId(unitId, modelId)
    if self.s2mUnitIdMapping[unitId] then
        self:removeUnit(unitId)
    end
    if self.m2sUnitIdMapping[modelId] then
        self:removeUnitByModelId(modelId)
    end
    self:addUnit(unitId, modelId)
end

function UnitManager:getUnit(triggerId)
    return self.triggers[triggerId]
end

function UnitManager:getAllUnits()
    local allUnits = {}
    for id, _ in pairs(self.m2sUnitIdMapping) do
        table.insert(allUnits, id)
    end
    return allUnits
end

function UnitManager:serialize()
    local retVal = {}
    for _, unit in pairs(self:allUnits()) do
        table.insert(retVal, 
            {
                unit = unit,
            }
        )
    end
    return retVal
end

function UnitManager:load(data)
    self:clear()
    self.unitIdCount = 0
    for _, kv in pairs(data) do
        id = kv.id
        unit = kv.unit
        self:addUnit(unit)
    end
end

function UnitManager:clear()
    for unitId, _ in pairs(self.s2mUnitIdMapping) do
        self:removeUnit(unitId)
    end
    self.s2mUnitIdMapping = {}
    self.m2sUnitIdMapping = {}
    self.unitIdCounter = 0
end
