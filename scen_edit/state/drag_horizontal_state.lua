DragHorizontalObjectState = AbstractState:extends{}

function DragHorizontalObjectState:init(startY)
    self.dy = 0
    self.startDiffY = startDiffY
    self.ghostViews = {
        units = {},
        features = {},
        areas = {},
    }
    SCEN_EDIT.SetMouseCursor("resize-y")
end

function DragHorizontalObjectState:GetMovedObjects()
    local selection = SCEN_EDIT.view.selectionManager:GetSelection()
    local objects = {
        units = {},
        features = {},
        areas = {},
    }
    for _, unitID in pairs(selection.units) do
        local unitX, unitY, unitZ = Spring.GetUnitPosition(unitID)
        local position = { unitX, unitY + self.dy, unitZ}
        objects.units[unitID] = position
    end
    for _, featureID in pairs(selection.features) do
        local unitX, unitY, unitZ = Spring.GetFeaturePosition(featureID)
        local position = { unitX, unitY + self.dy, unitZ}
        objects.features[featureID] = position
    end
    return objects
end

function DragHorizontalObjectState:MouseMove(x, y, dx, dy, button)
    self.dy = self.dy + dy

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

function DragHorizontalObjectState:MouseRelease(x, y, button)
    local commands = {}
    local movedObjects = self:GetMovedObjects()
    for unitID, pos in pairs(movedObjects.units) do
        local modelID = SCEN_EDIT.model.unitManager:getModelUnitId(unitID)
        local cmd = MoveUnitCommand(modelID, pos[1], pos[2], pos[3])
        table.insert(commands, cmd)
        table.insert(commands, SetUnitPropertyCommand(modelID, "gravity", 0))
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

function DragHorizontalObjectState:DrawWorld()
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
DragHorizontalUnitState = DragHorizontalObjectState:extends{}
function DragHorizontalUnitState:init(...)
    DragHorizontalObjectState.init(self, ...)
    self.bridge = unitBridge
end

DragHorizontalFeatureState = DragHorizontalObjectState:extends{}
function DragHorizontalFeatureState:init(...)
    DragHorizontalObjectState.init(self, ...)
    self.bridge = featureBridge
end