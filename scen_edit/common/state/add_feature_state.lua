AddFeatureState = AbstractState:extends{}

function AddFeatureState:init(featureDef, teamId, featureImages)
    self.featureDef = featureDef
    self.teamId = teamId
    self.featureImages = featureImages
    self.x, self.y, self.z = 0, 0, 0
    self.angle = 0
end

function AddFeatureState:enterState()
end

function AddFeatureState:leaveState()
end

function AddFeatureState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            self.x, self.y, self.z = unpack(coords)
            return true
        end
        return true
    elseif button == 3 then
        featureImages:SelectItem(0)
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function AddFeatureState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local dx = coords[1] - self.x
        local dz = coords[3] - self.z

        local len = math.sqrt(dx * dx + dz * dz)
        if len > 10 then
            self.angle = math.atan2(dx / len, dz / len) / math.pi * 180
        end
    end
end

function AddFeatureState:MouseRelease(x, y, button)
    local cmd = AddFeatureCommand(self.featureDef, self.x, self.y, self.z, self.teamId, self.angle)
    SCEN_EDIT.commandManager:execute(cmd)
    self.x, self.y, self.z = 0, 0, 0
    self.angle = 0
    return true
end

function AddFeatureState:KeyPress(key, mods, isRepeat, label, unicode)
end

function AddFeatureState:DrawWorld()
    local x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local drawX, drawY, drawZ = unpack(coords)
        gl.PushMatrix()
        gl.Color(1, 1, 1, 0.2)

        
        if self.x ~= 0 or self.y ~= 0 or self.z ~= 0 then
            gl.Translate(self.x, self.y, self.z)
            gl.Rotate(self.angle, 0, 1, 0)
        else
            gl.Translate(drawX, drawY, drawZ)
        end

        local feature = FeatureDefs[self.featureDef]
        local drawFeature = feature.drawType
        if drawFeature == 0 then
            drawFeature = self.featureDef
        end
        gl.FeatureShape(drawFeature, self.teamId)
        gl.PopMatrix()			
    end
end
