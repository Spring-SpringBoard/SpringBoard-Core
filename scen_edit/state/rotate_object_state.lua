RotateObjectState = AbstractState:extends{}

function RotateObjectState:init()
    AbstractState.init(self)
    SB.SetMouseCursor("resize-x")
    self.ghostViews = {}
end

function RotateObjectState:GetRotatedObject(params, bridge)
    local objectID = params.objectID
    local angle = params.angle
    local avgX, avgZ = params.avgX, params.avgZ

    local pos = bridge.s11n:Get(objectID, "pos")
    local objectX, objectY, objectZ = pos.x, pos.y, pos.z
    local dx = objectX - avgX
    local dz = objectZ - avgZ
    local angle2 = angle + math.atan2(dx, dz)
    local len = math.sqrt(dx * dx + dz * dz)

    local objectAngle = 0
    if bridge.s11n.getFuncs.dir then
        local dir = bridge.s11n:Get(objectID, "dir")
        objectAngle = math.atan2(dir.x, dir.z) + angle
    end

    local object = {
        angle = objectAngle,
        pos = {
            x = objectX,
            y = objectY,
            z = objectZ,
        }
    }
    if len > 0 then
        local x, z = avgX + len * math.sin(angle2), avgZ + len * math.cos(angle2)
        if math.abs(objectY - Spring.GetGroundHeight(objectX, objectZ)) < 5 then -- on ground, stick to it
            objectY = Spring.GetGroundHeight(x, z)
        end
        object.pos = {
            x = x,
            y = objectY,
            z = z,
        }
    end
    return object
end

function RotateObjectState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result ~= "ground" then
        return
    end

    local selection = SB.view.selectionManager:GetSelection()
    local selCount  = SB.view.selectionManager:GetSelectionCount()
    local avg = {x=0, y=0, z=0}
    for selType, selected in pairs(selection) do
        local bridge = ObjectBridge.GetObjectBridge(selType)
        for _, objectID in pairs(selected) do
            local pos = bridge.s11n:Get(objectID, "pos")
            avg.x = avg.x + pos.x
            avg.y = avg.y + pos.y
            avg.z = avg.z + pos.z
        end
    end

    avg.x = avg.x / selCount
    avg.y = avg.y / selCount
    avg.z = avg.z / selCount

    local dx, dz = coords[1] - avg.x, coords[3] - avg.z
    local angle = math.atan2(dx, dz)
    if self.angle == nil then
        self.angle = angle
    end
    angle = angle - self.angle

    self.ghostViews = {}
    for selType, selected in pairs(selection) do
        local bridge = ObjectBridge.GetObjectBridge(selType)
        self.ghostViews[selType] = {}
        for _, objectID in pairs(selected) do
            local object = self:GetRotatedObject({
                objectID = objectID,
                angle = angle,
                avgX = avg.x,
                avgZ = avg.z,
            }, bridge)
            self.ghostViews[selType][objectID] = object
        end
    end
end

function RotateObjectState:MouseRelease(x, y, button)
    if not self.ghostViews then
        return
    end

    local commands = {}

    for objType, objects in pairs(self.ghostViews) do
        local bridge = ObjectBridge.GetObjectBridge(objType)
        for objectID, object in pairs(objects) do
            local modelID = bridge.getObjectModelID(objectID)
            local opts = {
                pos = object.pos
            }
            if bridge.s11n.setFuncs.dir then
                opts.dir = { x = math.sin(object.angle), y = 0, z = math.cos(object.angle) }
            end
            local cmd = SetObjectParamCommand(bridge.name, modelID, opts)
            table.insert(commands, cmd)
        end
    end

    local compoundCommand = CompoundCommand(commands)
    SB.commandManager:execute(compoundCommand)

    SB.stateManager:SetState(DefaultState())
end

function RotateObjectState:DrawObject(objectID, object, bridge, shaderObj)
    local objectDefID  = bridge.GetObjectDefID(objectID)
    local objectTeamID = bridge.s11n:Get(objectID, "team")
    gl.Uniform(shaderObj.teamColorID, Spring.GetTeamColor(objectTeamID))
    bridge.DrawObject({
        color           = { r = 0.4, g = 1, b = 0.4, a = 0.8 },
        objectDefID     = objectDefID,
        objectTeamID    = objectTeamID,
        pos             = object.pos,
        angle           = { x = 0, y = math.deg(object.angle), z = 0 },
    })
end

function RotateObjectState:DrawWorld()
    if not self.ghostViews then
        return
    end
    gl.PushAttrib(GL.DEPTH_BUFFER_BIT)
    gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(true)

    local shaderObj = SB.view.modelShaders:GetShader()
    gl.UseShader(shaderObj.shader)
    gl.Uniform(shaderObj.timeID, os.clock())
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
