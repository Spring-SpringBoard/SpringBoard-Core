AreaModel = {
	area = {},
	unitsInArea = {},
}

function AreaModel:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self	
    return o
end

function AreaModel:UnitInArea(unitId)
	local x, y, z = Spring.GetUnitPosition(unitId)	
	return x >= self.area[1] and x < self.area[3] and z >= self.area[2] and z < self.area[4]
end

function AreaModel:UpdateUnit(unitId)
	local unitInside = self:UnitInArea(unitId)
	if unitInside then
		if self.unitsInArea[unitId] then			
			return 'none'
		else
			self.unitsInArea[unitId] = true
			return 'enter'
		end		
	else
		if self.unitsInArea[unitId] then
			self.unitsInArea[unitId] = nil
			return 'leave'
		else
			return 'none'
		end
	end
end

function AreaModel:Populate(unitIds)
	local results = { entered = {}, left = {} }
	for i = 1, #unitIds do
		local unitId = unitIds[i]
		local result = self:UpdateUnit(unitId)
		if result == 'enter' then
			table.insert(results.entered, unitId)
		elseif result == 'leave' then
			table.insert(results.left, unitId)
		end
	end
	return results
end