RemoveFeatureCommand = UndoableCommand:extends{}
RemoveFeatureCommand.className = "RemoveFeatureCommand"

function RemoveFeatureCommand:init(modelFeatureId)
    self.className = "RemoveFeatureCommand"
    self.modelFeatureId = modelFeatureId
end

function RemoveFeatureCommand:execute()
    local featureId = SCEN_EDIT.model.featureManager:getSpringFeatureId(self.modelFeatureId)
    self.featureTypeId = Spring.GetFeatureDefID(featureId)
    self.x, self.y, self.z = Spring.GetFeaturePosition(featureId)
    self.teamId = Spring.GetFeatureTeam(featureId)
    local dirX, _, dirZ = Spring.GetFeatureDirection(featureId)
    self.angle = math.atan2(dirX, dirZ) * 180 / math.pi

    Spring.DestroyFeature(featureId, false, true)--]]
end

function RemoveFeatureCommand:unexecute()
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
    Spring.SetFeatureDirection(featureId, x, 0, z)
    SCEN_EDIT.model.featureManager:setFeatureModelId(featureId, self.modelFeatureId)
end
