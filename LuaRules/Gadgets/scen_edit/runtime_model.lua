RuntimeModel = LCS.class{}

function RuntimeModel:init()
	self.areaModels = {}	
	self.lastFrameUnitIds = {}
	self.fieldResolver = FieldResolver()
end

function RuntimeModel:LoadMission()
	self.lastFrameUnitIds = Spring.GetAllUnits()
	self.areaModels = {}
	
    local areas = SCEN_EDIT.model.areaManager:getAllAreas()
	for id, area in pairs(areas) do
		local areaModel = AreaModel(id, area)
		areaModel:Populate(self.lastFrameUnitIds)
		table.insert(self.areaModels, areaModel)		
	end
	
	self.eventTriggers = {}
    local triggers = SCEN_EDIT.model.triggerManager:getAllTriggers()
	for id, trigger in pairs(triggers) do
        for j = 1, #trigger.events do
            local event = trigger.events[j]
            if not self.eventTriggers[event.eventTypeName] then
                self.eventTriggers[event.eventTypeName] = {}
            end
            table.insert(self.eventTriggers[event.eventTypeName], trigger)
        end
	end	
end

function RuntimeModel:GameStart()
    self.hasStarted = true
	if self.eventTriggers["GAME_START"] then
		for k = 1, #self.eventTriggers["GAME_START"] do
			local params = { }
			local trigger = self.eventTriggers["GAME_START"][k]				
			self:ConditionStep(trigger, params)
		end
	end
end

function RuntimeModel:GameStop()
    self.hasStarted = false
end

function RuntimeModel:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
    if not self.hasStarted then
        return
    end
	if self.eventTriggers["UNIT_DESTROY"] then
        local destroyedUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
		for k = 1, #self.eventTriggers["UNIT_DESTROY"] do
			local params = { triggerUnitId = destroyedUnitId }
			local trigger = self.eventTriggers["UNIT_DESTROY"][k]				
			self:ConditionStep(trigger, params)
		end
	end
end

function RuntimeModel:GameFrame(frameNum)
    if not self.hasStarted then
        return
    end
	local newUnitIds = Spring.GetAllUnits()	
	local unitIds = {}
	--update area-unit models
	for i = 1, #newUnitIds do
		local newId = newUnitIds[i]
		local found = false
		for j = 1, #self.lastFrameUnitIds do
			local oldId = self.lastFrameUnitIds[j]
			if newId == oldId then
				found = true
				break
			end
		end
		if found then
			table.insert(unitIds, newId)
		end
	end	
	--check for any enter/leave area events
	for i = 1, #self.areaModels do		
		local areaModel = self.areaModels[i]
		local results = areaModel:Populate(unitIds)
		local area = areaModel.area
		if self.eventTriggers["UNIT_ENTER_AREA"] then
			for j = 1, #results.entered do
				local enteredUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(results.entered[j])
				for k = 1, #self.eventTriggers["UNIT_ENTER_AREA"] do
					local params = { triggerUnitId = enteredUnitId, triggerAreaId = areaModel.id}
					local trigger = self.eventTriggers["UNIT_ENTER_AREA"][k]				
					self:ConditionStep(trigger, params)
				end
			end
		end
		if self.eventTriggers["UNIT_LEAVE_AREA"] then
			for j = 1, #results.left do
				local leftUnitId = results.left[j]
				for k = 1, #self.eventTriggers["UNIT_LEAVE_AREA"] do
					local params = { triggerUnitId = enteredUnitId, triggerAreaId = areaModel.id }
					local trigger = self.eventTriggers["UNIT_LEAVE_AREA"][k]				
					self:ConditionStep(trigger, params)
				end
			end
		end
		areaModel:Populate(newUnitIds)
	end	
	self.lastFrameUnitIds = newUnitIds
end

function RuntimeModel:ConditionStep(trigger, params)
	if not trigger.enabled then
		return
	end
	self.fieldResolver.params = params
	local cndSatisfied = self:ComputeTriggerConditions(trigger, params)
	if cndSatisfied then
		self:ActionStep(trigger, params)
	end
end

function RuntimeModel:ActionStep(trigger, params)
	for i = 1, #trigger.actions do
		local action = trigger.actions[i]
		local actionType = SCEN_EDIT.model.actionTypes[action.actionTypeName]
		local resolvedInputs = {}
		local fail = false
		for i = 1, #actionType.input do
			local input = actionType.input[i]	
			local resolvedInput = self.fieldResolver:Resolve(action[input.name], input.type)
            fail = fail or SCEN_EDIT.resolveAssert(resolvedInput, input, action)
			resolvedInputs[input.name] = resolvedInput
		end
		if not fail then
			if not actionType.execute then
				SCEN_EDIT.Error("There is no function execute for action type: " .. actionType.name)
			else				
				actionType.execute(resolvedInputs)
			end
		end
	end
end

function RuntimeModel:ExecuteTriggerActions(triggerId)
    if self.hasStarted then
        local trigger = SCEN_EDIT.model.triggerManager:getTrigger(triggerId)
        self:ActionStep(trigger, {})
    end
end

function RuntimeModel:ExecuteTrigger(triggerId)
    if self.hasStarted then
        local trigger = SCEN_EDIT.model.triggerManager:getTrigger(triggerId)
        self:ConditionStep(trigger, {})
    end
end

function RuntimeModel:ComputeTriggerConditions(trigger, params)
	for i = 1, #trigger.conditions do
		local condition = trigger.conditions[i]
		local conditionType = SCEN_EDIT.model.conditionTypes[condition.conditionTypeName]
		local resolvedInputs = {}
		local fail = false
		for i = 1, #conditionType.input do
			local input = conditionType.input[i]	
			local resolvedInput = self.fieldResolver:Resolve(condition[input.name], input.type)

            fail = fail or SCEN_EDIT.resolveAssert(resolvedInput, input, condition)
			resolvedInputs[input.name] = resolvedInput
		end
		if not fail then
			if not conditionType.execute then
				Spring.Echo("There is no function execute for condition type: " .. conditionType.name)
			else
				if not conditionType.execute(resolvedInputs) then
					return false
				end
			end
        else
            return false
        end
	end
	return true
end
