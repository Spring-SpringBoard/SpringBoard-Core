Model = {
    areas = {}, 
    triggers = {},
    variables = {},
    variableTypes = {"unit", "unitType", "team", "player", "area", "string", "number", "bool"},
    _triggerIdCount = 0,
    _variableIdCount = 0,
	C_HEIGHT = 16,
	B_HEIGHT = 26,
	eventTypes = {
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
	},
}

function Model:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self		
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
	
	table.echo(conditionTypes)
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
	
    return o
end

function Model:AddUnit(unitDef, x, y, z, playerId)
    Spring.SendLuaRulesMsg("scenedit|addUnit|" .. unitDef .. "|" .. 
        x .. "|" .. y .. "|" .. z .. "|" .. playerId)
end

function Model:RemoveUnit(unitId)
    Spring.SendLuaRulesMsg("scenedit|removeUnit|" .. unitId)
end

function Model:MoveUnit(unitId, x, y, z)
    Spring.SendLuaRulesMsg("scenedit|moveUnit|" .. unitId .. "|" .. 
        x .. "|" .. y .. "|" .. z .. "|")
end

function Model:AdjustHeightMap(x, z, height)
	Spring.SendLuaRulesMsg("scenedit|terr_inc|" .. x.. "|" .. 
        z .. "|" .. height)
end

--clears all units, areas, triggers, etc.
function Model:Clear()
    self.areas = {}
    self.triggers = {}
    self.variables = {}
    local allUnits = Spring.GetAllUnits()
    for i = 1, #allUnits do
        local unitId = allUnits[i]
        Model:RemoveUnit(unitId)
    end
end

function Model:Save(fileName)
	local mission = {}
	mission.meta = self:GetMetaData()
	mission.units = {}
	
    local allUnits = Spring.GetAllUnits()
    for i = 1, #allUnits do
        local unit = {}
        local unitId = allUnits[i]
        local unitDefId = Spring.GetUnitDefID(unitId)
        unit.unitDefName = UnitDefs[unitDefId].name
        unit.x, _, unit.y = Spring.GetUnitPosition(unitId)
        unit.player = Spring.GetUnitTeam(unitId)

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
	--load units
    local units = mission.units
    for i, unit in pairs(units) do
        self:AddUnit(unit.unitDefName, unit.x, 0, unit.y, unit.player)
    end
	
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
	}
end

--sets triggers, areas, etc.
function Model:SetMetaData(meta)
	self.areas = meta.areas
	self.triggers = meta.triggers
	self.variables = meta.variables
end

function Model:NewTrigger()
    self._triggerIdCount = self._triggerIdCount + 1
    local trigger = { 
        id = self._triggerIdCount,
        name = "Trigger " .. self._triggerIdCount,
        events = {},
        conditions = {},
        actions = {},
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

function Model:NewVariable()
    self._variableIdCount = self._variableIdCount + 1
    local variable = {
        id = self._variableIdCount,
        type = "number",
        value = 0,
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
    for i = 1, #self.variables do
        local tr = self.variables[i]
        if tr.id == variableId then
            table.remove(self.variables, i)
            return true
        end
    end
    return false
end
