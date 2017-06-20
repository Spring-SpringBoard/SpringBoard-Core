AreaModel = LCS.class{}

function AreaModel:init(id)
    self.id = id
    self.unitsInArea = {}
end

function AreaModel:UnitInArea(unitID)
    local x, y, z = Spring.GetUnitPosition(unitID)
    local area = SB.model.areaManager:getArea(self.id)
    local res = x >= area[1] and x < area[3] and z >= area[2] and z < area[4]
    return res
end

function AreaModel:UpdateUnit(unitID)
    local unitInside = self:UnitInArea(unitID)
    if unitInside then
        if self.unitsInArea[unitID] then
            return 'none'
        else
            self.unitsInArea[unitID] = true
            return 'enter'
        end
    else
        if self.unitsInArea[unitID] then
            self.unitsInArea[unitID] = nil
            return 'leave'
        else
            return 'none'
        end
    end
end

function AreaModel:Populate(unitIDs)
    local results = { entered = {}, left = {} }
    for i = 1, #unitIDs do
        local unitID = unitIDs[i]
        local result = self:UpdateUnit(unitID)
        if result == 'enter' then
            table.insert(results.entered, unitID)
        elseif result == 'leave' then
            table.insert(results.left, unitID)
        end
    end
    return results
end
