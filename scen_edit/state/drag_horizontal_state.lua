DragHorizontalObjectState = AbstractState:extends{}

function DragHorizontalObjectState:init(startY)
    AbstractState.init(self)

    self.dy = 0
    self.startDiffY = startDiffY
    SB.SetMouseCursor("resize-y")
end

function DragHorizontalObjectState:GetMovedObjects()
    local selection = SB.view.selectionManager:GetSelection()
    local objects = {}
    for selType, selected in pairs(selection) do
        objects[selType] = {}
        local bridge = ObjectBridge.GetObjectBridge(selType)
        if not bridge.NoHorizontalDrag and not bridge.NoDrag then
            for _, objectID in pairs(selected) do
                local pos = bridge.s11n:Get(objectID, "pos")
                pos.y = pos.y + self.dy
                objects[selType][objectID] = { pos = pos }
            end
        end
    end
    return objects
end

function DragHorizontalObjectState:MouseMove(x, y, dx, dy, button)
    self.dy = self.dy + dy
    self.ghostViews = self:GetMovedObjects()
end

function DragHorizontalObjectState:MouseRelease(x, y, button)
    local commands = {}
    local movedObjects = self:GetMovedObjects()
    for objType, objs in pairs(movedObjects) do
        local bridge = ObjectBridge.GetObjectBridge(objType)
        for objectID, obj in pairs(objs) do
            local modelID = bridge.getObjectModelID(objectID)
            table.insert(commands, bridge.SetObjectParamCommand(modelID, "pos", obj.pos))
            if bridge.s11n.setFuncs.gravity then
                table.insert(commands, bridge.SetObjectParamCommand(modelID, "gravity", 0))
            end
        end
    end
    local compoundCommand = CompoundCommand(commands)
    SB.commandManager:execute(compoundCommand)

    SB.stateManager:SetState(DefaultState())
end

function DragHorizontalObjectState:DrawObject(objectID, object, bridge, shaderObj)
    local objectDefID         = bridge.spGetObjectDefID(objectID)
    local objectTeamID        = bridge.s11n:Get(objectID, "team")
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
    if not self.ghostViews then
        return
    end
    gl.PushAttrib(GL.DEPTH_BUFFER_BIT)
    gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(true)
    local shaderObj = SB.view.modelShaders:GetShader()
    gl.UseShader(shaderObj.shader)
    gl.Uniform(shaderObj.timeID, os.clock())
    if not self.ghostViews then
        return
    end

    if self.ghostViews.unit then
        for objectID, object in pairs(self.ghostViews.unit) do
            self:DrawObject(objectID, object, unitBridge, shaderObj)
        end
    end
    if self.ghostViews.feature then
        for objectID, object in pairs(self.ghostViews.feature) do
            self:DrawObject(objectID, object, featureBridge, shaderObj)
        end
    end
    gl.UseShader(0)

    for objType, objs in pairs(self.ghostViews) do
        if objType ~= "unit" and objType ~= "feature" then
            local bridge = ObjectBridge.GetObjectBridge(objType)
            if bridge.DrawObject then
                for objectID, object in pairs(objs) do
                    bridge.DrawObject(objectID, object)
                end
            end
        end
    end
    gl.PopAttrib(GL.DEPTH_BUFFER_BIT)
end
