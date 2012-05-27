RuntimeModel = {
	areaModels = {},	
	model = {},
	eventTriggers = {
		UNIT_ENTER_AREA = {},
		UNIT_LEAVE_AREA = {},
	},
	lastFrameUnitIds = {},	
}

function RuntimeModel:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self	
	self.fieldResolver = FieldResolver:New {
		model = self.model,
	}
    return o
end

function RuntimeModel:LoadMission(model)
	self.lastFrameUnitIds = Spring.GetAllUnits()
	self.areaModels = None

	self.model = model	
	self.fieldResolver.model = model
	for i = 1, #model.areas do
		local area = model.areas[i]
		local areaModel = AreaModel:New({
			area = area,
		})
		areaModel:Populate(self.lastFrameUnitIds)
		table.insert(self.areaModels, areaModel)
	end
	
	for i = 1, #model.triggers do
		local trigger = model.triggers[i]
		for j = 1, #trigger.events do
			local event = trigger.events[j]
			if event.eventTypeName == "UNIT_ENTER_AREA" or event.eventTypeName == "UNIT_LEAVE_AREA" then
				table.insert(self.eventTriggers[event.eventTypeName], trigger)
			end
		end
	end	
end

function RuntimeModel:GameFrame(frameNum)
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
		for j = 1, #results.entered do
			local enteredUnitId = results.entered[j]
			for k = 1, #self.eventTriggers["UNIT_ENTER_AREA"] do
				local params = { triggerUnitId = enteredUnitId }
				local trigger = self.eventTriggers["UNIT_ENTER_AREA"][k]
				self:ConditionStep(trigger, params)
			end
		end
		for j = 1, #results.left do
			local leftUnitId = results.left[j]
			for k = 1, #self.eventTriggers["UNIT_LEAVE_AREA"] do
				local params = { triggerUnitId = enteredUnitId }
				local trigger = self.eventTriggers["UNIT_LEAVE_AREA"][k]
				self:ConditionStep(trigger, params)
			end
		end
		areaModel:Populate(newUnitIds)
	end
	self.lastFrameUnitIds = newUnitIds
end

function RuntimeModel:ConditionStep(trigger, params)
	self.fieldResolver.params = params
	local cndSatisfied = self:ComputeTriggerConditions(trigger)
	if cndSatisfied then
		self:ActionStep(trigger, params)
	end
end

function RuntimeModel:ActionStep(trigger, params)
	for i = 1, #trigger.actions do
		local action = trigger.actions[i]
		if action.actionTypeName == "SPAWN_UNIT" then
			local areaId = self.fieldResolver:Resolve(action.area, "area")
			local unitTypeId = self.fieldResolver:Resolve(action.unitType, "unitType")	
			local teamId = self.fieldResolver:Resolve(action.team, "team")
					
			if areaId ~= nil and unitTypeId ~= nil and teamId ~= nil then
				local area = self.model.areas[areaId]
				local x = (area[1] + area[3]) / 2
				local y = 0
				local z = (area[2] + area[4]) / 2
				--TODO: add player information
				GG.Delay.DelayCall(Spring.CreateUnit, {unitTypeId, x, y, z, 0, teamId})
			end
		elseif action.actionTypeName == "DESTROY_UNIT" then
			local unitId = self.fieldResolver:Resolve(action.unit, "unit")			
			
			if unitId ~= nil then
				GG.Delay.DelayCall(Spring.DestroyUnit, {unitId, false, true})
			end
		elseif action.actionTypeName == "MOVE_UNIT" then
			local areaId = self.fieldResolver:Resolve(action.area, "area")		
			local unitId = self.fieldResolver:Resolve(action.unit, "unit")					
			
			if unitId ~= nil and areaId ~= nil then
				local area = self.model.areas[areaId]
				local x = (area[1] + area[3]) / 2
				local y = 0
				local z = (area[2] + area[4]) / 2
				GG.Delay.DelayCall(Spring.SetUnitPosition, {unitId, x, y, z})
				-- TODO: this is wrong and shouldn't be needed; but it seems that a glitch is causing units to create a move order to their previous position
				GG.Delay.DelayCall(Spring.GiveOrderToUnit, {tonumber(unitId), CMD.STOP, {}, {}})
			end
		elseif action.actionTypeName == "TRANSFER_UNIT" then
			local unitId = self.fieldResolver:Resolve(action.unit, "unit")	
			local teamId = self.fieldResolver:Resolve(action.team, "team")
			
			if unitId ~= nil and teamId~= nil then
				GG.Delay.DelayCall(Spring.TransferUnit, {unitId, teamId, false})
			end
		end
	end
end

function RuntimeModel:ComputeTriggerConditions(trigger)
--TODO: add code
	return true
end