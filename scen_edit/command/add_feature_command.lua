AddFeatureCommand = UndoableCommand:extends{}
AddFeatureCommand.className = "AddFeatureCommand"

function AddFeatureCommand:init(featureTypeId, x, y, z, featureTeamId, angle)
    self.className = "AddFeatureCommand"
    self.x, self.y, self.z = x, y, z
    self.featureTypeId = featureTypeId
    self.featureTeamId = featureTeamId
    self.angle = angle
end

function AddFeatureCommand:execute()
    local featureId = Spring.CreateFeature(self.featureTypeId, self.x, self.y, self.z, 0, self.featureTeamId)
    local prop = math.tan(self.angle / 180 * math.pi)
    local z = math.sqrt(1 / (prop * prop + 1))
    local x = prop * z
    self.angle = math.abs(self.angle % 360)
    if self.angle >= 90 and self.angle < 180 then
        x = -x
        z = -z
    elseif self.angle >= 180 and self.angle < 270 then
        x = -x
        z = -z
    end
--[[    x^2 + y^2 = 1
    x = prop * y
    prop ^2 * y^2  + y^2 = 1
    y^2(prop^2 + 1) = 1
    y^2 = 1 / (prop^2 + 1)
    

    x * y
    x / (x^2 + y^2)
    y / (x^2 + y^2)
    
    local featureId = Spring.CreateFeature(self.featureTypeId, self.x, self.y, self.z, 0, self.featureTeamId)
    --]]
    if featureId then
        Spring.SetFeatureDirection(featureId, x, 0, z)
        if self.modelFeatureId == nil then
            self.modelFeatureId = SCEN_EDIT.model.featureManager:getModelFeatureId(featureId)
        else
            SCEN_EDIT.model.featureManager:setFeatureModelId(featureId, self.modelFeatureId)
        end
    end
end

function AddFeatureCommand:unexecute()
    if self.modelFeatureId then
        local featureId = SCEN_EDIT.model.featureManager:getSpringFeatureId(self.modelFeatureId)
        Spring.DestroyFeature(featureId, false, true)
    end
end
