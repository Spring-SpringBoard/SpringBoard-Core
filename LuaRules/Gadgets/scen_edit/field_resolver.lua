FieldResolver = {
	params = {},
	model = {},
}

function FieldResolver:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self	
    return o
end

function FieldResolver:Resolve(field, type)	
	if type == "unit" then
		local unitId = nil
		if field.type == "pred" then
			unitId = tonumber(field.id)
		elseif field.type == "spec" then
			if field.name == "Trigger unit" then
				unitId = tonumber(self.params.triggerUnitId)
			end
		elseif field.type == "var" then
		end
		if unitId ~= nil then
			return SCEN_EDIT.rtModel.model.unitManager:getSpringUnitId(unitId)
		end
	elseif type == "unitType" then		
		if field.type == "pred" then
			return tonumber(field.id)
		elseif field.type == "spec" then
			if field.name == "Trigger unit type" then
				local triggerUnitId = tonumber(self.params.triggerUnitId)
				if triggerUnitId then
					return Spring.GetUnitDefID(triggerUnitId)						
				end
			end
		end
	elseif type == "team" then
		if field.type == "pred" then
			return SCEN_EDIT.rtModel.model.teams[field.id]
		end
	elseif type == "area" then
		if field.type == "pred" then
			local areaId = tonumber(field.id)
            return self.model.areaManager:getArea(areaId)
		elseif field.type == "spec" then
			if field.name == "Trigger area" then
				local areaId = tonumber(self.params.triggerAreaId)
				if areaId then
					return self.model.areaManager:getArea(areaId)
				end
			end
		end
	elseif type == "trigger" then
		if field.type == "pred" then
			local triggerId = tonumber(field.id)
			return self.model.triggerManager:getTrigger(triggerId)
		end
	elseif type == "order" then
		local orderType = SCEN_EDIT.rtModel.model.orderTypes[field.orderTypeName]
		local order = {
			orderTypeName = field.orderTypeName,
			input = {}
		}
		for i = 1, #orderType.input do
			local input = orderType.input[i]	
			local resolvedInput = self:Resolve(field[input.name], input.type)
			order.input[input.name] = resolvedInput
		end
		return order
    elseif type == "string" then
        if field.type == "pred" then
            return field.string
        end
	elseif type == "numericComparison" then
		return self.model.numericComparisonTypes[field.cmpTypeId]
	elseif type == "identityComparison" then
		return self.model.identityComparisonTypes[field.cmpTypeId]
	end
end
