AreaModel = LCS.class{}

function AreaModel:init(id, area)
    self.id = id
    self.area = area
    self.unitsInArea = {}    
end

function AreaModel:UnitInArea(unitId)
    local x, y, z = Spring.GetUnitPosition(unitId)
    local res = x >= self.area[1] and x < self.area[3] and z >= self.area[2] and z < self.area[4]    
    return res
end

function AreaModel:UpdateUnit(unitId)
    local unitInside = self:UnitInArea(unitId)
    if unitInside then
        if self.unitsInArea[unitId] then            
            return 'none'
        else
            self.unitsInArea[unitId] = true
            local area = self.area
            --Spring.Echo("E", unitId, self.id, area[1], area[2], area[3], area[4])
            return 'enter'
        end        
    else
        if self.unitsInArea[unitId] then
            self.unitsInArea[unitId] = nil
            local area = self.area
            --Spring.Echo("L", unitId, self.id, area[1], area[2], area[3], area[4])
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
