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

function UnitManager:serializeUnitProperties(unitId, unit)
    unit.id = self:getModelUnitId(unitId)
    local dirX, dirY, dirZ = Spring.GetUnitDirection(unitId)
    unit.angle = math.atan2(dirX, dirZ) * 180 / math.pi
    
    unit.health = Spring.GetUnitHealth(unitId)
    _, unit.maxhealth = Spring.GetUnitHealth(unitId)
    if unit.maxhealth == UnitDefs[Spring.GetUnitDefID(unitId)].health then
        if unit.health == unit.maxhealth then
            unit.health = nil
        end
        unit.maxhealth = nil
    end
    unit.tooltip = Spring.GetUnitTooltip(unitId)
    unit.stockpile = Spring.GetUnitStockpile(unitId)
    unit.experience = Spring.GetUnitExperience(unitId)
    unit.fuel = Spring.GetUnitFuel(unitId)
    unit.states = Spring.GetUnitStates(unitId)
end

function UnitManager:serializeUnit(unitId)
    local unit = {}

    local unitDefId = Spring.GetUnitDefID(unitId)
    unit.unitDefName = UnitDefs[unitDefId].name
    unit.x, unit.y, unit.z = Spring.GetUnitPosition(unitId)
    unit.teamId = Spring.GetUnitTeam(unitId)
    self:serializeUnitProperties(unitId, unit)

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

function UnitManager:setUnitProperties(unitId, unit)
    local x = math.sin(math.rad(unit.angle))
    local z = math.cos(math.rad(unit.angle))
    Spring.SetUnitDirection(unitId, x, 0, z)
    if unit.maxhealth ~= nil then
        Spring.SetUnitMaxHealth(unitId, unit.maxhealth)
    end
    if unit.health ~= nil then
        Spring.SetUnitHealth(unitId, unit.health)
    end
    if unit.tooltip ~= nil then
        Spring.SetUnitTooltip(unitId, unit.tooltip)
    end
    if unit.stockpile ~= nil then
        Spring.SetUnitStockpile(unitId, unit.stockpile)
    end
    if unit.experience ~= nil then
        Spring.SetUnitExperience(unitId, unit.experience)
    end
    if unit.fuel ~= nil then
        Spring.SetUnitFuel(unitId, unit.fuel)
    end
    if unit.states ~= nil then
        local s = unit.states
        if s.cloak ~= nil then
            Spring.GiveOrderToUnit(unitId, CMD.INSERT,
                { 0, CMD.CLOAK, 0, boolToNumber(s.cloak)},
                {"alt"}
            );
        end
        if s.firestate ~= nil then
            Spring.GiveOrderToUnit(unitId, CMD.INSERT,
                { 0, CMD.FIRE_STATE, 0, s.firestate},
                {"alt"}
            );
        end
        if s.movestate ~= nil then
            Spring.GiveOrderToUnit(unitId, CMD.INSERT,
                { 0, CMD.MOVE_STATE, 0, s.movestate},
                {"alt"}
            );
        end
        -- setting the active state doesn't work currently
        --[[
        if s.active ~= nil then
            Spring.GiveOrderToUnit(unitId, CMD.INSERT,
                { 0, CMD.IDLEMODE, 0, boolToNumber(s.active)},
                {"alt"}
            );
        end
        --]]
        if s["repeat"] ~= nil then
            Spring.GiveOrderToUnit(unitId, CMD.INSERT,
                { 0, CMD.REPEAT, 0, boolToNumber(s["repeat"])},
                {"alt"}
            );
        end
    end
end

function UnitManager:loadUnit(unit)
    local unitId = Spring.CreateUnit(unit.unitDefName, unit.x, unit.y, unit.z, 0, unit.teamId)
    if unitId == nil then
        Spring.Echo("Failed to create the following unit: ")
        table.echo(unit)
        return
    end
    self:setUnitProperties(unitId, unit)
    self:setUnitModelId(unitId, unit.id)

    return unitId
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
