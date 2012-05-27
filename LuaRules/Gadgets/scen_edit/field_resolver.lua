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
		if field.type == "pred" then
			return tonumber(field.id)
		elseif field.type == "spec" then
			if field.name == "Trigger unit" then
				return tonumber(self.params.triggerUnitId)
			end
		elseif field.type == "var" then
		end
	elseif type == "unitType" then		
		if field.type == "spec" then
			if field.name == "Trigger unit type" then
				local triggerUnitId = tonumber(self.params.triggerUnitId)
				if triggerUnitId then
					return Spring.GetUnitDefID(triggerUnitId)						
				end
			end
		end
	elseif type == "team" then
		if field.type == "pred" then
			return tonumber(field.id)
		end
	elseif type == "area" then
		if field.type == "pred" then
			return tonumber(field.id)			
		end
	end
end