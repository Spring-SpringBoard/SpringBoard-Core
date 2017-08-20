DragObjectState = AbstractState:extends{}

function DragObjectState:init(objectID, bridge, startDiffX, startDiffZ)
    AbstractState.init(self)

    self.objectID = objectID
    self.bridge = bridge
    self.dx = 0
    self.dz = 0
    self.startDiffX = startDiffX
    self.startDiffZ = startDiffZ
    SB.SetMouseCursor("drag")
end

function DragObjectState:GetMovedObjects()
    local selection = SB.view.selectionManager:GetSelection()
    local objects = {}
    for selType, selected in pairs(selection) do
        objects[selType] = {}
        local bridge = ObjectBridge.GetObjectBridge(selType)
        for _, objectID in pairs(selected) do
            local pos = bridge.s11n:Get(objectID, "pos")
            local dy = pos.y - Spring.GetGroundHeight(pos.x, pos.z)
            pos.x = pos.x + self.dx
            pos.z = pos.z + self.dz
            pos.y = Spring.GetGroundHeight(pos.x, pos.z) + dy
            objects[selType][objectID] = { pos = pos }
        end
    end
    return objects
end

function DragObjectState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result ~= "ground" then
        return
    end

    if not self.bridge.ValidObject(self.objectID) then -- or Spring.GetUnitIsDead(self.objectID)
        SB.stateManager:SetState(DefaultState())
        return false
    end
    local pos = self.bridge.s11n:Get(self.objectID, "pos")
    self.dx = coords[1] - pos.x + self.startDiffX
    self.dz = coords[3] - pos.z + self.startDiffZ

    self.ghostViews = self:GetMovedObjects()
end

function DragObjectState:MouseRelease(x, y, button)
    local commands = {}
    local movedObjects = self:GetMovedObjects()
    for objType, objs in pairs(movedObjects) do
        local bridge = ObjectBridge.GetObjectBridge(objType)
        for objectID, obj in pairs(objs) do
            local modelID = bridge.getObjectModelID(objectID)
            local cmd = SetObjectParamCommand(bridge.name, modelID, "pos", obj.pos)
            table.insert(commands, cmd)
        end
    end

    local compoundCommand = CompoundCommand(commands)
    SB.commandManager:execute(compoundCommand)

    SB.stateManager:SetState(DefaultState())
end

function DragObjectState:DrawObject(objectID, object, bridge, shaderObj)
    local objectDefID         = bridge.GetObjectDefID(objectID)
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

function DragObjectState:DrawWorld()
    if not self.ghostViews then
        return
    end

    gl.PushAttrib(GL.DEPTH_BUFFER_BIT)
    gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(true)
    local shaderObj = SB.view.modelShaders:GetShader()

    gl.UseShader(shaderObj.shader)
    gl.Uniform(shaderObj.timeID, os.clock())

    for objectID, object in pairs(self.ghostViews.unit) do
        self:DrawObject(objectID, object, unitBridge, shaderObj)
    end
    for objectID, object in pairs(self.ghostViews.feature) do
        self:DrawObject(objectID, object, featureBridge, shaderObj)
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
