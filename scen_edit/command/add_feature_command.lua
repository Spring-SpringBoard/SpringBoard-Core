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
    local x = math.sin(math.rad(self.angle))
    local z = math.cos(math.rad(self.angle))
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
