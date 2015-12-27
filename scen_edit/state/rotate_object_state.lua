RotateObjectState = AbstractState:extends{}

function RotateObjectState:init()
    self.ghostViews = {
        units = {},
        features = {},
        areas = {},
    }
    SCEN_EDIT.SetMouseCursor("resize-x")
end

function RotateObjectState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then

        local selection = SCEN_EDIT.view.selectionManager:GetSelection()
        self.ghostViews = {
            units = {},
            features = {},
            areas = {},
        }

        local avgX, avgZ = 0, 0
        for _, unitID in pairs(selection.units) do
            local unitX, unitY, unitZ = Spring.GetUnitPosition(unitID)
            avgX = avgX + unitX
            avgZ = avgZ + unitZ
        end
        for _, featureID in pairs(selection.features) do
            local unitX, unitY, unitZ = Spring.GetFeaturePosition(featureID)
            avgX = avgX + unitX
            avgZ = avgZ + unitZ
        end
        avgX = avgX / (#selection.features + #selection.units)
        avgZ = avgZ / (#selection.features + #selection.units)
        local dx, dz = coords[1] - avgX, coords[3] - avgZ
        local angle = math.atan2(dx, dz)
        if self.angle == nil then
            self.angle = angle
        end
        angle = angle - self.angle

        for _, unitID in pairs(selection.units) do
            local unitX, unitY, unitZ = Spring.GetUnitPosition(unitID)
            local dx = unitX - avgX
            local dz = unitZ - avgZ
            local angle2 = angle + math.atan2(dx, dz)
            local len = math.sqrt(dx * dx + dz * dz)

            local dirX, _, dirZ = Spring.GetUnitDirection(unitID)
            local objectAngle = math.atan2(dirX, dirZ)
            objectAngle = objectAngle + angle
            self.ghostViews.units[unitID] = {
                angle = objectAngle,
                pos = {
                    x = unitX,
                    y = unitY,
                    z = unitZ,
                }
            }
            if len > 0 then
                local x, z = avgX + len * math.sin(angle2), avgZ + len * math.cos(angle2)
                if math.abs(unitY - Spring.GetGroundHeight(unitX, unitZ)) < 5 then -- on ground, stick to it
                    unitY = Spring.GetGroundHeight(x, z)
                end
                self.ghostViews.units[unitID].pos = {
                    x = x,
                    y = unitY,
                    z = z,
                }
            end
        end
        for _, featureID in pairs(selection.features) do
            local unitX, unitY, unitZ = Spring.GetFeaturePosition(featureID)
            local dx = unitX - avgX
            local dz = unitZ - avgZ
            local angle2 = angle + math.atan2(dx, dz)
            local len = math.sqrt(dx * dx + dz * dz)

            local dirX, _, dirZ = Spring.GetFeatureDirection(featureID)
            local objectAngle = math.atan2(dirX, dirZ)
            objectAngle = objectAngle + angle
            self.ghostViews.features[featureID] = {
                angle = objectAngle,
                pos = {
                    x = unitX,
                    y = unitY,
                    z = unitZ,
                }
            }
            if len > 0 then
                local x, z = avgX + len * math.sin(angle2), avgZ + len * math.cos(angle2)
                if math.abs(unitY - Spring.GetGroundHeight(unitX, unitZ)) < 5 then -- on ground, stick to it
                    unitY = Spring.GetGroundHeight(x, z)
                end
                self.ghostViews.features[featureID].pos = {
                    x = x,
                    y = unitY,
                    z = z,
                }
            end
        end
    end
end

function RotateObjectState:MouseRelease(x, y, button)
    local commands = {}

    for unitID, object in pairs(self.ghostViews.units) do
        local modelID = SCEN_EDIT.model.unitManager:getModelUnitId(unitID)
        local rotateCommand = RotateUnitCommand(modelID, object.angle * 180 / math.pi)
        table.insert(commands, rotateCommand)
        local pos = object.pos
        local unitX, unitY, unitZ = pos.x, pos.y, pos.z
        local cmd = MoveUnitCommand(modelID, unitX, unitY, unitZ)
        table.insert(commands, cmd)
    end
    for featureID, object in pairs(self.ghostViews.features) do
        local modelID = SCEN_EDIT.model.featureManager:getModelFeatureId(featureID)
        local rotateCommand = RotateFeatureCommand(modelID, object.angle * 180 / math.pi)
        table.insert(commands, rotateCommand)
        local pos = object.pos
        local unitX, unitY, unitZ = pos.x, pos.y, pos.z
        local cmd = MoveFeatureCommand(modelID, unitX, unitY, unitZ)
        table.insert(commands, cmd)
    end

    local compoundCommand = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(compoundCommand)

    SCEN_EDIT.stateManager:SetState(DefaultState())
end

function RotateObjectState:DrawObject(objectID, object, bridge)
    gl.PushMatrix()
    local objectDefID  = bridge.spGetObjectDefID(objectID)
    local objectTeamID = bridge.spGetObjectTeam(objectID)
    bridge.DrawObject({
        color           = { r = 0.4, g = 1, b = 0.4, a = 0.8 },
        objectDefID     = objectDefID,
        objectTeamID    = objectTeamID,
        pos             = object.pos,
        angle           = { x = 0, y = object.angle * 180 / math.pi, z = 0 },
    })
    gl.PopMatrix()
end

function RotateObjectState:DrawWorld()
    gl.PushMatrix()
    gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(true)
    for objectID, object in pairs(self.ghostViews.units) do
        self:DrawObject(objectID, object, unitBridge)
    end
    for objectID, object in pairs(self.ghostViews.features) do
        self:DrawObject(objectID, object, featureBridge)
    end
    gl.PopMatrix()
end
