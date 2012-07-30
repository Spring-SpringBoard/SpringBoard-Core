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
end

function RotateFeatureCommand:unexecute()
    local featureId = SCEN_EDIT.model.featureManager:getSpringFeatureId(self.modelFeatureId)
    Spring.SetFeatureDirection(featureId, self.oldX, self.oldY, self.oldZ)
end
