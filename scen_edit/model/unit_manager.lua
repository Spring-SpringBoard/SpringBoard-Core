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

function UnitManager:getAllUnits()
    local allUnits = {}
    for id, _ in pairs(self.m2sUnitIdMapping) do
        table.insert(allUnits, id)
    end
    return allUnits
end

function UnitManager:serialize()
    return unitBridge.s11n:Get(Spring.GetAllUnits())
end

-- function UnitManager:loadUnit(unit)
--     if self.m2sUnitIdMapping[unit.id] then
--         return
--     end
--     -- FIXME: figure out why this sometimes fails on load with a specific unit.id
--     local unitId = Spring.CreateUnit(unit.unitDefName, unit.x, unit.y, unit.z, 0, unit.teamId, false, true)
--     if unitId == nil then
--         Log.Error("Failed to create the following unit: " .. table.show(unit))
--         return
--     end
--     -- FIXME: this check is not usable until unit creation by ID is fixed
--     if false and unit.id ~= nil and unit.id ~= unitId then
--         Log.Error("Created unit has different id: " .. tostring(unit.id) .. ", " .. tostring(unitId))
--     end
--     self:setUnitProperties(unitId, unit)
--     self:setUnitModelId(unitId, unit.id)
--     if unit.commands ~= nil then
--         self:setUnitCommands(unitId, unit.commands)
--     end
--     return unitId
-- end

function UnitManager:load(units)
    self.unitIdCounter = 0
    if #units > 0 then
        unitBridge.s11n:Add(units)
    end
    -- -- load the units without the commands
    -- local unitCommands = {}
    -- for _, unit in pairs(units) do
    --     local commands = unit.commands
    --     unit.commands = nil
    --     local unitId = self:loadUnit(unit)
    --     if unitId then
    --         unitCommands[unitId] = commands
    --     end
    -- end
    -- -- load the commands
    -- for unitId, commands in pairs(unitCommands) do
    --     self:setUnitCommands(unitId, commands)
    -- end
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
------------------------------------------------
-- Listener definition
------------------------------------------------
UnitManagerListener = LCS.class.abstract{}

function UnitManagerListener:onUnitAdded(unitId, modelId)
end

function UnitManagerListener:onUnitRemoved(unitId, modelId)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
