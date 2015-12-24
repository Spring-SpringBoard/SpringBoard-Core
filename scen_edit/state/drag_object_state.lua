DragObjectState = AbstractState:extends{}

function DragObjectState:init(objectID, startDiffX, startDiffZ)
    self.objectID = objectID
    self.dx = 0
    self.dz = 0
    self.startDiffX = startDiffX
    self.startDiffZ = startDiffZ
    self.ghostViews = {
        units = {},
        features = {},
        areas = {},
    }
    SCEN_EDIT.SetMouseCursor("drag")
end

-- function DragObjectState:GameFrame(frameNum)
--     local objectIDs = SCEN_EDIT.view.selectionManager:GetSelection().units
--     for i = 1, #objectIDs do
--         local objectID = objectIDs[i]
--         if not Spring.ValidUnitID(objectID) or Spring.GetUnitIsDead(objectID) then
--             SCEN_EDIT.stateManager:SetState(DefaultState())
--             return false
--         end
--     end
-- end

function DragObjectState:GetMovedObjects()
    local selection = SCEN_EDIT.view.selectionManager:GetSelection()
    local objects = {
        units = {},
        features = {},
        areas = {},
    }
    for _, unitID in pairs(selection.units) do
        local unitX, unitY, unitZ = Spring.GetUnitPosition(unitID)
        local y = Spring.GetGroundHeight(unitX + self.dx, unitZ + self.dz)
        local position = { unitX + self.dx, y, unitZ + self.dz}
        objects.units[unitID] = position
    end
    for _, featureID in pairs(selection.features) do
        local unitX, unitY, unitZ = Spring.GetFeaturePosition(featureID)
        local y = Spring.GetGroundHeight(unitX + self.dx, unitZ + self.dz)
        local position = { unitX + self.dx, y, unitZ + self.dz}
        objects.features[featureID] = position
    end
    return objects
end

function DragObjectState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        if not self.bridge.spValidObject(self.objectID) then -- or Spring.GetUnitIsDead(self.objectID) 
            SCEN_EDIT.stateManager:SetState(DefaultState())
            return false
        end
        local unitX, unitY, unitZ = self.bridge.spGetObjectPosition(self.objectID)
        self.dx = coords[1] - unitX + self.startDiffX
        self.dz = coords[3] - unitZ + self.startDiffZ

        self.ghostViews = {
            units = {},
            features = {},
            areas = {},
        }
        local movedObjects = self:GetMovedObjects()
        for unitID, position in pairs(movedObjects.units) do
            self.ghostViews.units[unitID] = position
        end
        for featureID, position in pairs(movedObjects.features) do
            self.ghostViews.features[featureID] = position
        end
    end
end

function DragObjectState:MouseRelease(x, y, button)
    local commands = {}
    local movedObjects = self:GetMovedObjects()
    for unitID, pos in pairs(movedObjects.units) do
        local modelID = SCEN_EDIT.model.unitManager:getModelUnitId(unitID)
        local cmd = MoveUnitCommand(modelID, pos[1], pos[2], pos[3])
        table.insert(commands, cmd)
    end
    for featureID, pos in pairs(movedObjects.features) do
        local modelID = SCEN_EDIT.model.featureManager:getModelFeatureId(featureID)
        local cmd = MoveFeatureCommand(modelID, pos[1], pos[2], pos[3])
        table.insert(commands, cmd)
    end

    local compoundCommand = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(compoundCommand)

    SCEN_EDIT.stateManager:SetState(DefaultState())
end

function DragObjectState:DrawWorld()
    for objectID, pos in pairs(self.ghostViews.units) do
        gl.PushMatrix()
        local unitType = Spring.GetUnitDefID(objectID)
        local unitTeamId = Spring.GetUnitTeam(objectID)
        gl.Translate(pos[1], pos[2], pos[3])

        local dirX, dirY, dirZ = Spring.GetUnitDirection(objectID)
        local angleY = math.atan2(dirX, dirZ)

        if angleY ~= 0 then
            gl.Rotate(180 / math.pi * angleY, 0, 1, 0)
        end

        gl.Color(0.1, 1, 0.1, 0.8)
--        gl.UnitRaw(objectID, true)
        gl.UnitShape(unitType, unitTeamId)
        gl.PopMatrix()
    end
    for featureId, pos in pairs(self.ghostViews.features) do
        gl.PushMatrix()
		gl.Color(1, 1, 1, 0.5)
        local featureDefId = Spring.GetFeatureDefID(featureId)
        local featureTeamId = Spring.GetFeatureTeam(featureId)
        gl.Translate(pos[1], pos[2], pos[3])

        local dirX, dirY, dirZ = Spring.GetFeatureDirection(featureId)
        local angleY = math.atan2(dirX, dirZ)

        if angleY ~= 0 then
            gl.Rotate(180 / math.pi * angleY, 0, 1, 0)
        end

        gl.Texture(1, "%-" .. featureDefId .. ":1")
        gl.FeatureShape(featureDefId, featureTeamId)
        gl.PopMatrix()
    end
end

-- Custom unit/feature classes
DragUnitState = DragObjectState:extends{}
function DragUnitState:init(...)
    DragObjectState.init(self, ...)
    self.bridge = unitBridge
end

DragFeatureState = DragObjectState:extends{}
function DragFeatureState:init(...)
    DragObjectState.init(self, ...)
    self.bridge = featureBridge
end