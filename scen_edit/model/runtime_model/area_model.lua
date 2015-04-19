AreaModel = LCS.class{}

function AreaModel:init(id)
    self.id = id
    self.unitsInArea = {}    
end

function AreaModel:UnitInArea(unitId)
    local x, y, z = Spring.GetUnitPosition(unitId)
    local area = SCEN_EDIT.model.areaManager:getArea(self.id)
    local res = x >= area[1] and x < area[3] and z >= area[2] and z < area[4]    
    return res
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
