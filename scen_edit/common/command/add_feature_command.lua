AddFeatureCommand = UndoableCommand:extends{}
SCEN_EDIT.SetClassName(AddFeatureCommand, "AddFeatureCommand")

function AddFeatureCommand:init(featureTypeId, x, y, z, featureTeamId, angle)
    self.className = "AddFeatureCommand"
    self.x, self.y, self.z = x, y, z
    self.featureTypeId = featureTypeId
    self.featureTeamId = featureTeamId
    self.angle = angle
end

function AddFeatureCommand:execute()
    self.featureId = Spring.CreateFeature(self.featureTypeId, self.x, self.y, self.z, 0, self.featureTeamId)
    Spring.SetFeatureDirection(self.featureId, 0, self.angle, 0)
    local prop = math.tan(self.angle)
    local z = math.sqrt(1 / (prop * prop + 1))
    local x = prop * z
--[[    x^2 + y^2 = 1
    x = prop * y
    prop ^2 * y^2  + y^2 = 1
    y^2(prop^2 + 1) = 1
    y^2 = 1 / (prop^2 + 1)
    

    x * y
    x / (x^2 + y^2)
    y / (x^2 + y^2)--]]
    Spring.SetFeatureDirection(self.featureId, x, 0, z)
    --[[
    local featureId = Spring.CreateFeature(self.featureTypeId, self.x, self.y, self.z, 0, self.featureTeamId)
    if self.modelFeatureId == nil then
        self.modelFeatureId = SCEN_EDIT.model.featureManager:getModelFeatureId(featureId)
    else
        SCEN_EDIT.model.featureManager:setFeatureModelId(featureId, self.modelFeatureId)
    end--]]
end

function AddFeatureCommand:unexecute()
    --[[local featureId = SCEN_EDIT.model.featureManager:getSpringFeatureId(self.modelFeatureId)
    Spring.DestroyFeature(featureId, false, true)--]]
    Spring.DestroyFeature(self.featureId, false, true)--]]
end
