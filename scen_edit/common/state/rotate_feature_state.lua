RotateFeatureState = AbstractState:extends{}

function RotateFeatureState:init(featureId)
    self.featureId = featureId
    
    
    self.featureGhostViews = {}
    local x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    self.newPosX = coords[1]
    self.newPosZ = coords[3]
    self.initialRots = {}
    local featureIds = {self.featureId} --Spring.GetSelectedFeatures()
    for i = 1, #featureIds do
        local featureId = featureIds[i]
        local featureX, featureY, featureZ = Spring.GetFeaturePosition(featureId)

        local dirX, dirY, dirZ = Spring.GetFeatureDirection(featureId)
        local oldAngle = math.atan2(dirX, dirZ) * 180 / math.pi
        self.initialRots[featureId] = oldAngle
        local dx = self.newPosX - featureX
        local dz = self.newPosZ - featureZ

        local len = math.sqrt(dx * dx + dz * dz)
        local newAngle = 0
        if len > 0 then
            local angle = { dx / len, dz / len}
            newAngle = math.atan2(angle[1], angle[2]) / math.pi * 180
        end
        self.initialRots[featureId] = self.initialRots[featureId] - newAngle
    end
end

function RotateFeatureState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        self.newPosX = coords[1]
        self.newPosZ = coords[3]
        local featureIds = {self.featureId} --Spring.GetSelectedFeatures()
        self.featureGhostViews = {}
    
        for i = 1, #featureIds do
            local featureId = featureIds[i]
            local featureX, featureY, featureZ = Spring.GetFeaturePosition(featureId)
            local dx = self.newPosX - featureX
            local dz = self.newPosZ - featureZ

            local len = math.sqrt(dx * dx + dz * dz)
            if len > 0 then
                local angle = { dx / len, dz / len}
                self.featureGhostViews[featureId] = math.atan2(angle[1], angle[2]) / math.pi * 180 + self.initialRots[featureId]
            end
        end
    end
end

function RotateFeatureState:MouseRelease(x, y, button)
    local commands = {}
    for featureId, angle in pairs(self.featureGhostViews) do
        local modelFeatureId = SCEN_EDIT.model.featureManager:getModelFeatureId(featureId)
        local rotateCommand = RotateFeatureCommand(modelFeatureId, angle)
        table.insert(commands, rotateCommand)
    end
    local compoundCommand = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(compoundCommand)
    SCEN_EDIT.stateManager:SetState(DefaultState())
end

function RotateFeatureState:DrawWorld()
    for featureId, angle in pairs(self.featureGhostViews) do
        gl.PushMatrix()
        gl.Color(0.1, 1, 0.1, 0.4)
        local featureType = Spring.GetFeatureDefID(featureId)
        local featureTeamId = Spring.GetFeatureTeam(featureId)
        local featureX, featureY, featureZ = Spring.GetFeaturePosition(featureId)
        gl.Translate(featureX, featureY, featureZ)

        gl.Rotate(angle, 0, 1, 0)

--       gl.FeatureRaw(featureId, true)
        gl.FeatureShape(featureType, featureTeamId)
        gl.PopMatrix()
    end
end
