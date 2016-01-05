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
        local position = { x = unitX, y = unitY + self.dy, z = unitZ}
        objects.units[unitID] = { pos = position }
    end
    for _, featureID in pairs(selection.features) do
        local unitX, unitY, unitZ = Spring.GetFeaturePosition(featureID)
        local position = { x = unitX, y = unitY + self.dy, z = unitZ}
        objects.features[featureID] = { pos = position }
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
    for unitID, object in pairs(movedObjects.units) do
        local modelID = SCEN_EDIT.model.unitManager:getModelUnitId(unitID)
        local cmd = SetUnitParamCommand(modelID, "pos", object.pos)
        table.insert(commands, cmd)
        table.insert(commands, SetUnitPropertyCommand(modelID, "gravity", 0))
    end
    for featureID, object in pairs(movedObjects.features) do
        local modelID = SCEN_EDIT.model.featureManager:getModelFeatureId(featureID)
        local cmd = SetFeatureParamCommand(modelID, "pos", object.pos)
        table.insert(commands, cmd)
    end

    local compoundCommand = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(compoundCommand)

    SCEN_EDIT.stateManager:SetState(DefaultState())
end

function DragHorizontalObjectState:DrawObject(objectID, object, bridge, shaderObj)
    local objectDefID         = bridge.spGetObjectDefID(objectID)
    local objectTeamID        = bridge.spGetObjectTeam(objectID)
    gl.Uniform(shaderObj.teamColorID, Spring.GetTeamColor(objectTeamID))
    local rot                 = bridge.s11n:Get(objectID, "rot")
    bridge.DrawObject({
        color           = { r = 0.4, g = 1, b = 0.4, a = 0.8 },
        objectDefID     = objectDefID,
        objectTeamID    = objectTeamID,
        pos             = object.pos,
        angle           = { x = -math.deg(rot.x), y = -math.deg(rot.y), z = -math.deg(rot.z)},
    })
end

function DragHorizontalObjectState:DrawWorld()
    gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(true)
    local shaderObj = SCEN_EDIT.view.modelShaders:GetShader()
    gl.UseShader(shaderObj.shader)
    gl.Uniform(shaderObj.timeID, os.clock())
    for objectID, object in pairs(self.ghostViews.units) do
        self:DrawObject(objectID, object, unitBridge, shaderObj)
    end
    for objectID, object in pairs(self.ghostViews.features) do
        self:DrawObject(objectID, object, featureBridge, shaderObj)
    end
    gl.UseShader(0)
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