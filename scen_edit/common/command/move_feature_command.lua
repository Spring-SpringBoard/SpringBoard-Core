MoveFeatureCommand = UndoableCommand:extends{}
MoveFeatureCommand.className = "MoveFeatureCommand"

function MoveFeatureCommand:init(modelFeatureId, newX, newY, newZ)
    self.className = "MoveFeatureCommand"
    self.modelFeatureId = modelFeatureId
    self.newX = newX
    self.newY = newY
    self.newZ = newZ
end

function MoveFeatureCommand:execute()
    local featureId = SCEN_EDIT.model.featureManager:getSpringFeatureId(self.modelFeatureId)
    local featureX, featureY, featureZ = Spring.GetFeaturePosition(featureId)
    self.oldX = featureX
    self.oldY = featureY
    self.oldZ = featureZ
    Spring.SetFeaturePosition(featureId, self.newX, self.newY, self.newZ)
--[[

    local feature = {}
    local featureDefId = Spring.GetFeatureDefID(featureId)
    feature.featureDefName = FeatureDefs[featureDefId].name
    feature.x, _, feature.y = Spring.GetFeaturePosition(featureId)
    feature.player = Spring.GetFeatureTeam(featureId)
    feature.id = SCEN_EDIT.model.featureManager:getModelFeatureId(featureId)
    local dirX, dirY, dirZ = Spring.GetFeatureDirection(featureId)
    feature.angle = math.atan2(dirX, dirZ) * 180 / math.pi

    Spring.DestroyFeature(featureId, false, true)
    local featureId = Spring.CreateFeature(feature.featureDefName, self.newX, self.newY, self.newZ, feature.player)
    local prop = math.tan(feature.angle / 180 * math.pi)
    local z = math.sqrt(1 / (prop * prop + 1))
    local x = prop * z
    feature.angle = math.abs(feature.angle % 360)
    if feature.angle >= 90 and feature.angle < 180 then
        x = -x
        z = -z
    elseif feature.angle >= 180 and feature.angle < 270 then
        x = -x
        z = -z
    end
    Spring.SetFeatureDirection(featureId, x, 0, z)
    SCEN_EDIT.model.featureManager:setFeatureModelId(featureId, feature.id)-]]
end

function MoveFeatureCommand:unexecute()
    local featureId = SCEN_EDIT.model.featureManager:getSpringFeatureId(self.modelFeatureId)
    Spring.SetFeaturePosition(featureId, self.oldX, self.oldY, self.oldZ)
end

