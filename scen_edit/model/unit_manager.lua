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
    unit.neutral = Spring.GetUnitNeutral(unitId)
    -- TODO: this isn't available
    -- unit.alwaysVisible = Spring.GetAlwaysVisible(unitId)
    -- FIXME: This returns multiple values, save them too?
    -- FIXME: There are some issues with this.. ignore saving for now
    --unit.blocking = Spring.GetUnitBlocking(unitId)
    unit.states = Spring.GetUnitStates(unitId)
    -- FIXME: why do we need the second param?
    unit.losState = Spring.GetUnitLosState(unitId, 0) -- los, radar and typed
    unit.rules = {}
    for rule, value in pairs(Spring.GetUnitRulesParams(unitId)) do
        unit.rules[rule] = value
    end
end

function UnitManager:serializeUnitCommands(unitId, unit)
    -- -1 needed here to work around jk's attempt at optimization (otherwise we get errors)
    unit.commands = Spring.GetUnitCommands(unitId, -1)
    if unit.commands ~= nil then
        for _, command in pairs(unit.commands) do
            if command.id >= 0 then
                command.name = CMD[command.id]
            else
                command.name = "BUILD_COMMAND"
                local buildUnitDef = UnitDefs[math.abs(command.id)]
                if buildUnitDef ~= nil then
                    command.buildUnitDef = buildUnitDef.name
                else
                    Log.Error("No such unit def: (" .. math.abs(command.id) ..  ") for build command: " .. tostring(command.id))
                end
            end
            command.options = nil
            command.tag = nil
            command.id = nil
            -- serialized unit commands use the model unit id
            if isUnitCommand(command) then
                command.params[1] = self:getModelUnitId(command.params[1])
            end
        end
    end
end

function UnitManager:serializeUnit(unitId)
    local unit = {}

    local unitDefId = Spring.GetUnitDefID(unitId)
    unit.unitDefName = UnitDefs[unitDefId].name
    unit.x, unit.y, unit.z = Spring.GetUnitPosition(unitId)
    unit.teamId = Spring.GetUnitTeam(unitId)

    self:serializeUnitProperties(unitId, unit)
    self:serializeUnitCommands(unitId, unit)

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
    if unit.neutral ~= nil then
        Spring.SetUnitNeutral(unitId, unit.neutral)
    end
    if unit.alwaysVisible ~= nil then
        Spring.SetUnitAlwaysVisible(unitId, unit.alwaysVisible)
    end
    if unit.blocking ~= nil then
        Spring.SetUnitBlocking(unitId, unit.blocking)
    end
    if unit.losState ~= nil then
        Spring.SetUnitLosState(unitId, 0, unit.losState)
    end
    if unit.unitDefName == "house" then
        Spring.SetUnitAlwaysVisible(unitId, true)
        Spring.SetUnitNeutral(unitId, true)
    end
    if unit.rules ~= nil then
        for _, foo in pairs(unit.rules) do
            if type(foo) == "table" then
                for rule, value in pairs(foo) do
                    Spring.SetUnitRulesParam(unitId, rule, value)
                end
            end
        end
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

function isUnitCommand(command)
    if command.params ~= nil and #command.params ~= 1 then
        return false
    end
    local unitCommands = { "DEATHWAIT", "ATTACK", "GUARD", "REPAIR", "LOAD_UNITS", "UNLOAD_UNITS", "RECLAIM", "RESSURECT", "CAPTURE", "LOOPBACKATTACK" }
    for _, unitCommand in pairs(unitCommands) do
        if command.name == unitCommand then
            return true
        end
    end
    return false
end

function UnitManager:setUnitCommands(unitId, commands)
    for _, command in pairs(commands) do
        local params
        -- unit commands need to get the real unit ID
        if isUnitCommand(command) then
            params = { self:getSpringUnitId(command.params[1]) }
        else
            params = command.params
        end
        if command.name ~= "BUILD_COMMAND" then
            Spring.GiveOrderToUnit(unitId, CMD[command.name], params, {"shift"})
        else
            Spring.GiveOrderToUnit(unitId, -UnitDefNames[command.buildUnitDef].id, params, {"shift"})
        end
    end
end

function UnitManager:loadUnit(unit)
    if self.m2sUnitIdMapping[unit.id] then
        return
    end
    if unit.unitDefName == "house" then
        unit.teamId = 2
    end
    -- FIXME: figure out why this sometimes fails on load with a specific unit.id
    local unitId = Spring.CreateUnit(unit.unitDefName, unit.x, unit.y, unit.z, 0, unit.teamId, false, true)
    if unitId == nil then
        Log.Error("Failed to create the following unit: " .. table.show(unit))
        return
    end
    -- FIXME: this check is not usable until unit creation by ID is fixed
    if false and unit.id ~= nil and unit.id ~= unitId then
        Log.Error("Created unit has different id: " .. tostring(unit.id) .. ", " .. tostring(unitId))
    end
    self:setUnitProperties(unitId, unit)
    self:setUnitModelId(unitId, unit.id)
    if unit.commands ~= nil then
        self:setUnitCommands(unitId, unit.commands)
    end
    return unitId
end

function UnitManager:load(units)
    self.unitIdCounter = 0
    -- load the units without the commands
    local unitCommands = {}
    for _, unit in pairs(units) do
        local commands = unit.commands
        unit.commands = nil
        local unitId = self:loadUnit(unit)
        if unitId then
            unitCommands[unitId] = commands
        end
    end
    -- load the commands
    for unitId, commands in pairs(unitCommands) do
        self:setUnitCommands(unitId, commands)
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
