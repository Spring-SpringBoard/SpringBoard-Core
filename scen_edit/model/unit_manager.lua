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
    local unitId = self.m2sUnitIdMapping[modelUnitId]
    if unitId ~= nil then
        return unitId
    else
        return modelUnitId
    end
end

function UnitManager:getModelUnitId(springUnitId)
    local unitId = self.s2mUnitIdMapping[springUnitId]
    if unitId ~= nil then
        return unitId
    else
        return springUnitId
    end
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

function UnitManager:serializeUnit(unitId)
    local unit = {}

    local unitDefId = Spring.GetUnitDefID(unitId)
    unit.unitDefName = UnitDefs[unitDefId].name
    unit.x, _, unit.y = Spring.GetUnitPosition(unitId)
    unit.player = Spring.GetUnitTeam(unitId)
    unit.id = self:getModelUnitId(unitId)
    local dirX, dirY, dirZ = Spring.GetUnitDirection(unitId)
    unit.angle = math.atan2(dirX, dirZ) * 180 / math.pi

    return unit
end

function UnitManager:serialize()
    local retVal = {}
    for _, unitId in pairs(Spring.GetAllUnits()) do
        local unit = self:serializeUnit(unitId)
        table.insert(retVal, unit)
    end
    return retVal
end

function UnitManager:loadUnit(unit)
    local unitId = Spring.CreateUnit(unit.unitDefName, unit.x, 0, unit.y, 0, unit.player)
    if unitId ~= nil then			
        local x = math.sin(math.rad(unit.angle))
        local z = math.cos(math.rad(unit.angle))
        Spring.SetUnitDirection(unitId, x, 0, z)
        self:setUnitModelId(unitId, unit.id)
    else
        Spring.Echo("Failed to create the following unit: ")
        table.echo(unit)
    end
end

function UnitManager:load(units)
    self:clear()

    self.unitIdCounter = 0
    for _, unit in pairs(units) do
        self:loadUnit(unit)
    end
end

function UnitManager:clear()
    for _, unitId in pairs(Spring.GetAllUnits()) do
        Spring.DestroyUnit(unitId, false, true)
        --self:removeUnit(unitId)
    end

    for unitId, _ in pairs(self.s2mUnitIdMapping) do
        self:removeUnit(unitId)
    end
    self.s2mUnitIdMapping = {}
    self.m2sUnitIdMapping = {}
    self.unitIdCounter = 0
end
