RotateFeatureCommand = AbstractCommand:extends{}
RotateFeatureCommand.className = "RotateFeatureCommand"

function RotateFeatureCommand:init(modelFeatureId, angle)
    self.className = "RotateFeatureCommand"
    self.modelFeatureId = modelFeatureId
    self.angle = angle
end

function RotateFeatureCommand:execute()
    local featureId = SCEN_EDIT.model.featureManager:getSpringFeatureId(self.modelFeatureId)
    self.oldX, self.oldY, self.oldZ = Spring.GetFeatureDirection(featureId)

    local x = math.sin(math.rad(self.angle))
    local z = math.cos(math.rad(self.angle))
    Spring.SetFeatureDirection(featureId, x, 0, z)
end

function RotateFeatureCommand:unexecute()
    local featureId = SCEN_EDIT.model.featureManager:getSpringFeatureId(self.modelFeatureId)
    Spring.SetFeatureDirection(featureId, self.oldX, self.oldY, self.oldZ)
end
