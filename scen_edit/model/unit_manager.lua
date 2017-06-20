UnitManager = Observable:extends{}

function UnitManager:init(widget)
    self:super('init')
    self.s2mUnitIDMapping = {}
    self.m2sUnitIDMapping = {}
    self.unitIDCounter = 0
    self.widget = widget
end

function UnitManager:populate()
    if not self.widget then
        local allUnits = Spring.GetAllUnits()
        for i = 1, #allUnits do
            local unitID = allUnits[i]
            self:addUnit(unitID)
        end
    end
end

function UnitManager:addUnit(unitID, modelID)
    if self.s2mUnitIDMapping[unitID] then
        return
    end
    if modelID ~= nil then
        if self.unitIDCounter < modelID then
            self.unitIDCounter = modelID
        end
    else
        self.unitIDCounter = self.unitIDCounter + 1
        modelID = self.unitIDCounter
    end
    if not self.s2mUnitIDMapping[unitID] then
        self.s2mUnitIDMapping[unitID] = modelID
    end
    if not self.m2sUnitIDMapping[modelID] then
        self.m2sUnitIDMapping[modelID] = unitID
    end

    self:callListeners("onUnitAdded", unitID, modelID)
    return modelID
end

function UnitManager:removeUnit(unitID)
    if unitID == nil then
        return
    end
    local modelID = self.s2mUnitIDMapping[unitID]
    if self.s2mUnitIDMapping[unitID] then
        self.m2sUnitIDMapping[modelID] = nil
    end
    self.s2mUnitIDMapping[unitID] = nil

    self:callListeners("onUnitRemoved", unitID, modelID)
end

function UnitManager:removeUnitByModelID(modelID)
    local springID = self.m2sUnitIDMapping[modelID]
    self:removeUnit(springID)
end

function UnitManager:getSpringUnitID(modelUnitID)
    return self.m2sUnitIDMapping[modelUnitID]
end

function UnitManager:getModelUnitID(springUnitID)
    return self.s2mUnitIDMapping[springUnitID]
end

function UnitManager:setUnitModelID(unitID, modelID)
    if self.s2mUnitIDMapping[unitID] then
        self:removeUnit(unitID)
    end
    if self.m2sUnitIDMapping[modelID] then
        self:removeUnitByModelID(modelID)
    end
    self:addUnit(unitID, modelID)
end

function UnitManager:getAllUnits()
    local allUnits = {}
    for id, _ in pairs(self.m2sUnitIDMapping) do
        table.insert(allUnits, id)
    end
    return allUnits
end

function UnitManager:serialize()
    return unitBridge.s11n:Get(Spring.GetAllUnits())
end

-- function UnitManager:loadUnit(unit)
--     if self.m2sUnitIDMapping[unit.id] then
--         return
--     end
--     -- FIXME: figure out why this sometimes fails on load with a specific unit.id
--     local unitID = Spring.CreateUnit(unit.unitDefName, unit.x, unit.y, unit.z, 0, unit.teamID, false, true)
--     if unitID == nil then
--         Log.Error("Failed to create the following unit: " .. table.show(unit))
--         return
--     end
--     -- FIXME: this check is not usable until unit creation by ID is fixed
--     if false and unit.id ~= nil and unit.id ~= unitID then
--         Log.Error("Created unit has different id: " .. tostring(unit.id) .. ", " .. tostring(unitID))
--     end
--     self:setUnitProperties(unitID, unit)
--     self:setUnitModelID(unitID, unit.id)
--     if unit.commands ~= nil then
--         self:setUnitCommands(unitID, unit.commands)
--     end
--     return unitID
-- end

function UnitManager:load(units)
    self.unitIDCounter = 0
    unitBridge.s11n:Add(units)
    -- -- load the units without the commands
    -- local unitCommands = {}
    -- for _, unit in pairs(units) do
    --     local commands = unit.commands
    --     unit.commands = nil
    --     local unitID = self:loadUnit(unit)
    --     if unitID then
    --         unitCommands[unitID] = commands
    --     end
    -- end
    -- -- load the commands
    -- for unitID, commands in pairs(unitCommands) do
    --     self:setUnitCommands(unitID, commands)
    -- end
end

function UnitManager:clear()
    for _, unitID in pairs(Spring.GetAllUnits()) do
        Spring.DestroyUnit(unitID, false, true)
        --self:removeUnit(unitID)
    end

    for unitID, _ in pairs(self.s2mUnitIDMapping) do
        self:removeUnit(unitID)
    end
    self.s2mUnitIDMapping = {}
    self.m2sUnitIDMapping = {}
    self.unitIDCounter = 0
end
------------------------------------------------
-- Listener definition
------------------------------------------------
UnitManagerListener = LCS.class.abstract{}

function UnitManagerListener:onUnitAdded(unitID, modelID)
end

function UnitManagerListener:onUnitRemoved(unitID, modelID)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
