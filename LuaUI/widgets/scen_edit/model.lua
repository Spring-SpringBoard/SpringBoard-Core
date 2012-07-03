Model = class()

function Model:__init()
    self.areas = {}
    self.triggers = {}
    self.variables = {}
	self.teams = {}    
    self._triggerIdCount = 0
    self._variableIdCount = 0
	self._lua_rules_pre = "scen_edit"
	self.C_HEIGHT = 16
	self.B_HEIGHT = 26
	self.numericComparisonTypes = {"==", "~=", "<=", ">=", ">", "<"} -- maybe use more user friendly signs
	self.identityComparisonTypes = {"is", "is not"} -- maybe use more user friendly signs
	self.eventTypes = {
		{
			humanName = "Game started",
			name = "GAME_START",
		}, 
		{
			humanName = "Game ends",
			name = "GAME_END",
		}, 
		{
			humanName = "Player died",
			name = "PLAYER_DIE",
		}, 
		{
			humanName = "Unit created",
			name = "UNIT_CREATE",
		},
		{
			humanName = "Unit damaged",
			name = "UNIT_DAMAGE",
		},
		{
			humanName = "Unit destroyed",
			name = "UNIT_DESTROY",
		},
		{
			humanName = "Unit finished",
			name = "UNIT_FINISH",
		},
		{
			humanName = "Unit enters area",
			name = "UNIT_ENTER_AREA",
		},
		{
			humanName = "Unit leaves area",
			name = "UNIT_LEAVE_AREA",
		},
	}
	
	self.eventTypes = CreateNameMapping(self.eventTypes)
	local actionTypes = SCEN_EDIT.coreActions()
	for i = 1, #actionTypes do
		local actionType = actionTypes[i]
		actionType.input = SCEN_EDIT.parseData(actionType.input)
	end
	self.actionTypes = CreateNameMapping(actionTypes)
	
	local conditionTypes = SCEN_EDIT.coreConditions() 
	for i = 1, #conditionTypes do
		local conditionType = conditionTypes[i]
		conditionType.input = SCEN_EDIT.parseData(conditionType.input)
	end
	self.conditionTypes = CreateNameMapping(conditionTypes)
	self.conditionTypesByInput = SCEN_EDIT.GroupByField(conditionTypes, "input")
	self.conditionTypesByOutput = SCEN_EDIT.GroupByField(conditionTypes, "output")
	
	local coreTypes = SCEN_EDIT.coreTypes()
	-- fill missing
	for i = 1, #coreTypes do
		local coreType = coreTypes[i]
		if self.conditionTypesByInput[coreType] then
			self.conditionTypesByInput[coreType] = CreateNameMapping(self.conditionTypesByInput[coreType])
		end
		if self.conditionTypesByOutput[coreType] then
			self.conditionTypesByOutput[coreType] = CreateNameMapping(self.conditionTypesByOutput[coreType])
		end
	end
	
	local orderTypes = SCEN_EDIT.coreOrders()
	for i = 1, #orderTypes do
		local orderType = orderTypes[i]
		orderType.input = SCEN_EDIT.parseData(orderType.input)
	end
	self.orderTypes = CreateNameMapping(orderTypes)
	
	--add variables for core types
	self.variableTypes = {"unit", "unitType", "team", "player", "area", "string", "number", "bool"}	
	--add array type
	--local arrayTypes = {}
	for i = 1, #self.variableTypes do
		local variableType = self.variableTypes[i]
		local arrayType = variableType .. "_array"
		table.insert(self.variableTypes, arrayType)
	end
	
	self.s2mUnitIdMapping = {}
	self.m2sUnitIdMapping = {}
	self._unitIdCounter = 0
	
	self.callbacks = {}
	self.callbackIdCount = 0
end

function Model:GetSpringUnitId(modelId)
	return self.m2sUnitIdMapping[modelId]
end

function Model:GetModelUnitId(springUnitId)
	return self.s2mUnitIdMapping[springUnitId]
end

function Model:AddedUnit(unitId)
	self._unitIdCounter = self._unitIdCounter + 1
	if not self.s2mUnitIdMapping[unitId] then
		self.s2mUnitIdMapping[unitId] = self._unitIdCounter
	end
	if not self.m2sUnitIdMapping[self._unitIdCounter] then
		self.m2sUnitIdMapping[self._unitIdCounter] = unitId
	end
end

function Model:RemovedUnit(unitId)
	if self.s2mUnitIdMapping[unitId] then
		self.m2sUnitIdMapping[self.s2mUnitIdMapping[unitId]] = nil
	end
	self.s2mUnitIdMapping[unitId] = nil
end

function Model:InvokeCallback(callbackId, params)
	self.callbacks[callbackId](unpack(params))
end

function Model:RemoveCallback(callbackId)
	self.callbacks[callbackId] = nil
end

function Model:GenerateCallbackId(callback)
	self.callbackIdCount = self.callbackIdCount + 1
	self.callbacks[self.callbackIdCount] = callback
	return self.callbackIdCount
end

function Model:AddUnit(unitDef, x, y, z, playerId, callback)
	local message = self._lua_rules_pre .. "|addUnit|" .. unitDef .. "|" .. 
        x .. "|" .. y .. "|" .. z .. "|" .. playerId
	if callback then
		message = message .. "|callback|" .. self:GenerateCallbackId(callback)
	end
    Spring.SendLuaRulesMsg(message)
end

function Model:RemoveUnit(unitId)
    Spring.SendLuaRulesMsg(self._lua_rules_pre .. "|removeUnit|" .. unitId)
end

function Model:AddFeature(featureDef, x, y, z, playerId)
    Spring.SendLuaRulesMsg(self._lua_rules_pre .. "|addFeature|" .. featureDef .. "|" .. 
        x .. "|" .. y .. "|" .. z .. "|" .. playerId)
end

function Model:RemoveFeature(unitId)
    Spring.SendLuaRulesMsg(self._lua_rules_pre .. "|removeFeature|" .. unitId)
end

function Model:MoveUnit(unitId, x, y, z)
    Spring.SendLuaRulesMsg(self._lua_rules_pre .. "|moveUnit|" .. unitId .. "|" .. 
        x .. "|" .. y .. "|" .. z .. "|")
end

function Model:AdjustHeightMap(x1, z1, x2, z2, height)
	Spring.SendLuaRulesMsg(self._lua_rules_pre .. "|terr_inc|" .. x1.. "|" .. 
        z1 .. "|" .. x2 .. "|" .. z2 .. "|" .. height)
end

function Model:RevertHeightMap(x1, z1, x2, z2)
	Spring.SendLuaRulesMsg(self._lua_rules_pre .. "|terr_rev|" .. x1.. "|" .. 
        z1 .. "|" .. x2 .. "|" .. z2 .. "|")
end

--clears all units, areas, triggers, etc.
function Model:Clear()
    self.areas = {}
    self.triggers = {}
    self.variables = {}
	self.teams = {}
    local allUnits = Spring.GetAllUnits()
    for i = 1, #allUnits do
        local unitId = allUnits[i]
        self:RemoveUnit(unitId)
    end
	local allFeatures = Spring.GetAllFeatures()
	for i = 1, #allFeatures do
		local featureId = allFeatures[i]
		self:RemoveFeature(featureId)
	end
	self._unitIdCounter = 0
	self.m2sUnitIdMapping = {}
	self.s2mUnitIdMapping = {}
end

function Model:Save(fileName)
	local mission = {}
	mission.meta = self:GetMetaData()
	mission.meta.m2sUnitIdMapping = {}
	mission.meta.s2mUnitIdMapping = {}
	mission.units = {}
	
    local allUnits = Spring.GetAllUnits()
    for i = 1, #allUnits do
        local unit = {}
        local unitId = allUnits[i]
        local unitDefId = Spring.GetUnitDefID(unitId)
        unit.unitDefName = UnitDefs[unitDefId].name
        unit.x, _, unit.y = Spring.GetUnitPosition(unitId)
        unit.player = Spring.GetUnitTeam(unitId)
		unit.id = self.s2mUnitIdMapping[unitId]

        table.insert(mission.units, unit)
    end
	
--[[    local mission = {}
    mission.triggers = {}
    table.insert(mission.triggers, {})
    mission.triggers[1].logic = {}

    

    -- add unit spawn
    local gameStart = {}
    gameStart.logicType = "GameStartedCondition"
    gameStart.args = {}
    gameStart.name = "Game Starts"
    table.insert(mission.triggers[1].logic, gameStart)

    local createUnits = {}
    createUnits.logicType = "CreateUnitsAction"
    createUnits.args = {}
    createUnits.args.units = units
    createUnits.name = "Create Units"
    table.insert(mission.triggers[1].logic, createUnits)

    -- save regions
    mission.regions = {}
    table.insert(mission.regions, {})
    mission.regions[1].areas = {}
    for i, area in pairs(self.areas) do
        local saveArea = {}
        saveArea.category = "rectangle"
        saveArea.x = area[1]
        saveArea.y = area[2]
        saveArea.width = area[3] - area[1]
        saveArea.height = area[4] - area[2]
        table.insert(mission.regions[1].areas, saveArea) 
    end
--]]
    -- write to file
    table.save(mission, fileName)
end

function Model:Load(fileName)
    self:Clear()
	
    --load file
    local f, err = loadfile(fileName)
    local mission = f()
	self:SetMetaData(mission.meta)
	self.m2sUnitIdMapping = {}
	self.s2mUnitIdMapping = {}
	--load units
    local units = mission.units
	self._unitIdCounter = 0
    for i, unit in pairs(units) do
        self:AddUnit(unit.unitDefName, unit.x, 0, unit.y, unit.player,
			function (unitId)				
				if self.s2mUnitIdMapping[unitId] then
					self.m2sUnitIdMapping[self.s2mUnitIdMapping[unitId]] = nil
				end				
				self.s2mUnitIdMapping[unitId] = unit.id
				self.m2sUnitIdMapping[unit.id] = unitId
			end
		)
		if unit.id > self._unitIdCounter then
			self._unitIdCounter = unit.id
		end
    end
	self:GenerateTeams()
--[[    
    if mission.regions ~= nil then
        local areas = mission.regions[1].areas
        for i, area in pairs(areas) do
            if area.category == "rectangle" then
                table.insert(areas, {area.x, area.y, area.x + area.width, 
                    area.y + area.height})
            end
        end
    end
	--]]
end

--returns a table that holds triggers, areas and other non-engine content
function Model:GetMetaData()
	return {
		areas = self.areas,
		triggers = self.triggers,
		variables = self.variables,
		teams = self.teams,
		s2mUnitIdMapping = self.s2mUnitIdMapping,
		m2sUnitIdMapping = self.m2sUnitIdMapping,
	}
end

--sets triggers, areas, etc.
function Model:SetMetaData(meta)
	self.areas = meta.areas
	self.triggers = meta.triggers
	for i = 1, #self.triggers do
		local trigger = self.triggers[i]
		if self._triggerIdCount < trigger.id then
			self._triggerIdCount = trigger.id
		end
	end
	self.variables = meta.variables
		for i = 1, #self.variables do
		local variable = self.variables[i]
		if self._variableIdCount < variable.id then
			self._variableIdCount = variable.id
		end
	end
	self.teams = meta.teams or {}
	self.s2mUnitIdMapping = meta.s2mUnitIdMapping or {}
	self.m2sUnitIdMapping = meta.m2sUnitIdMapping or {}
end

function Model:NewTrigger()
    self._triggerIdCount = self._triggerIdCount + 1
    local trigger = { 
        id = self._triggerIdCount,
        name = "Trigger " .. self._triggerIdCount,
        events = {},
        conditions = {},
        actions = {},
		enabled = true,
    }
    table.insert(self.triggers, trigger)
    return trigger
end

function Model:RemoveTrigger(triggerId)
    for i = 1, #self.triggers do
        local tr = self.triggers[i]
        if tr.id == triggerId then
            table.remove(self.triggers, i)
            return true
        end
    end
    return false
end

function Model:NewVariable(variableType)
    self._variableIdCount = self._variableIdCount + 1
    local variable = {
        id = self._variableIdCount,
        type = variableType,        
		value = {},
        name = "variable" .. self._variableIdCount,
    }
	if self.variables[variable.type] then
		table.insert(self.variables[variable.type], variable)
	else
		self.variables[variable.type] = {variable}
	end
    return variable
end

function Model:RemoveVariable(variableId)
    for k, v in pairs(self.variables) do
        for i = 1, #v do
			local variable = v[i]
			if variable.id == variableId then
				table.remove(self.variables[k], i)
				return true
			end
		end
    end
    return false
end

function Model:ListVariables()
	local allVars = {}
	for k, v in pairs(self.variables) do
		for i = 1, #v do
			local variable = v[i]
			table.insert(allVars, variable)
		end
	end
	return allVars
end

function Model:GetVariablesOfType(type)
	return self.variables[type]
end

--should be called from the widget upon creating a new model
function Model:GenerateTeams() 
	local names, ids, colors = GetTeams()
	for i = 1, #ids do
		local id = ids[i]
		local name = names[i]
		local color = colors[i]
		
		self.teams[id] = {
			name = name,
			id = id,
			color = color,
		}
	end
end
