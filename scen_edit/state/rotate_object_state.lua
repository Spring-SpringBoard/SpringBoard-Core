RotateObjectState = AbstractState:extends{}

function RotateObjectState:init()
    self.ghostViews = {
        units = {},
        features = {},
        areas = {},
    }
end

-- function RotateObjectState:GameFrame(frameNum)
--     local selType, unitIds = SCEN_EDIT.view.selectionManager:GetSelection()
--     for i = 1, #unitIds do
--         local unitId = unitIds[i]
--         if not Spring.ValidUnitID(unitId) or Spring.GetUnitIsDead(unitId) then
--             SCEN_EDIT.stateManager:SetState(DefaultState())
--             return false
--         end
--     end
-- end

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
                    z = unitZ,
                }
            }
            if len > 0 then
                self.ghostViews.units[unitID].pos = {
                    x = avgX + len * math.sin(angle2),
                    z = avgZ + len * math.cos(angle2),
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
                    z = unitZ,
                }
            }
            if len > 0 then
                self.ghostViews.features[featureID].pos = {
                    x = avgX + len * math.sin(angle2),
                    z = avgZ + len * math.cos(angle2),
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
        local unitX, unitZ = pos.x, pos.z
        local unitY = Spring.GetGroundHeight(unitX, unitZ)
        local cmd = MoveUnitCommand(modelID, unitX, unitY, unitZ)
        table.insert(commands, cmd)
    end
    for featureID, object in pairs(self.ghostViews.features) do
        local modelID = SCEN_EDIT.model.featureManager:getModelFeatureId(featureID)
        local rotateCommand = RotateFeatureCommand(modelID, object.angle * 180 / math.pi)
        table.insert(commands, rotateCommand)
        local pos = object.pos
        local unitX, unitZ = pos.x, pos.z
        local unitY = Spring.GetGroundHeight(unitX, unitZ)
        local cmd = MoveFeatureCommand(modelID, unitX, unitY, unitZ)
        table.insert(commands, cmd)
    end

    local compoundCommand = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(compoundCommand)

    SCEN_EDIT.stateManager:SetState(DefaultState())
end

function RotateObjectState:DrawWorld()
    for unitID, object in pairs(self.ghostViews.units) do
        gl.PushMatrix()
        local unitType = Spring.GetUnitDefID(unitID)
        local unitTeamId = Spring.GetUnitTeam(unitID)
        local pos = object.pos
        local unitX, unitZ = pos.x, pos.z
        local unitY = Spring.GetGroundHeight(unitX, unitZ)
        gl.Translate(unitX, unitY, unitZ)

        gl.Rotate(object.angle * 180 / math.pi, 0, 1, 0)

        gl.Color(0.1, 1, 0.1, 0.8)
--        gl.UnitRaw(unitID, true)
        gl.UnitShape(unitType, unitTeamId)
        gl.PopMatrix()
    end
    for featureID, object in pairs(self.ghostViews.features) do
        gl.PushMatrix()
		gl.Color(1, 1, 1, 0.5)
        local featureDefId = Spring.GetFeatureDefID(featureID)
        local featureTeamId = Spring.GetFeatureTeam(featureID)
        local pos = object.pos
        local unitX, unitZ = pos.x, pos.z
        local unitY = Spring.GetGroundHeight(unitX, unitZ)
        gl.Translate(unitX, unitY, unitZ)

        gl.Rotate(object.angle * 180 / math.pi, 0, 1, 0)

        gl.Texture(1, "%-" .. featureDefId .. ":1")
        gl.FeatureShape(featureDefId, featureTeamId)
        gl.PopMatrix()
    end
end
