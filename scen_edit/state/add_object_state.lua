AddObjectState = AbstractState:extends{}

function AddObjectState:init(bridge, editorView, objectDefIDs)
    AbstractState.init(self, editorView)

    self.bridge = bridge
    self.objectDefIDs = objectDefIDs

    self.x, self.y, self.z = 0, 0, 0
    self.angle = 0
    self.randomSeed = os.clock()

    -- self.mapGrid = MapGrid(100, 100)
    -- self.mapGrid.separatorSize = 1

    self.amount  = self.editorView.fields["amount"].value
    self.team    = self.editorView.fields["team"].value
end

function AddObjectState:MousePress(mx, my, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(mx, my, true)
        if result == "ground" then
            self.x, self.y, self.z = coords[1], coords[2], coords[3]
--             self.x, self.z = self.mapGrid:GetGridPosition(self.x, self.z)
--             self.y = Spring.GetGroundHeight(self.x, self.z)
            return true
        end
    elseif button == 3 then
        SB.stateManager:SetState(DefaultState())
    end
end

function AddObjectState:MouseMove(mx, my, ...)
    local result, coords = Spring.TraceScreenRay(mx, my, true)
    if result == "ground" then
        local dx = coords[1] - self.x
        local dz = coords[3] - self.z

        local len = math.sqrt(dx * dx + dz * dz)
        if len > 10 then
            self.angle = math.atan2(dx / len, dz / len)
        end
    end
end

function AddObjectState:MouseRelease(...)
    if not self.objectDefIDs or #self.objectDefIDs == 0 then
        return
    end

    local commands = {}
    math.randomseed(self.randomSeed)
    for i = 1, self.amount do
        local objectDefID = self.objectDefIDs[math.random(1, #self.objectDefIDs)]
        local x, y, z = self.x, self.y, self.z
        if i ~= 1 then
            x = x + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
            z = z + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
        end

        local dirX = math.sin(self.angle)
        local dirZ = math.cos(self.angle)
        local cmd = AddObjectCommand(self.bridge.name, {
            defName = objectDefID,
            pos = { x = x, y = y, z = z },
            dir = { x = dirX, y = 0, z = dirZ },
            team = self.team,
        })
        commands[#commands + 1] = cmd
    end

    local compoundCommand = CompoundCommand(commands)

    SB.commandManager:execute(compoundCommand)
    self.x, self.y, self.z = 0, 0, 0
    self.angle = 0
    self.randomSeed = self.randomSeed + os.clock()
end

function AddObjectState:DrawObject(object, bridge)
    local objectDefID         = object.objectDefID
    local objectTeamID        = object.objectTeamID
    local pos                 = object.pos
    local angleY              = object.angleY
    bridge.DrawObject({
        color           = { r = 0.4, g = 1, b = 0.4, a = 0.8 },
        objectDefID     = objectDefID,
        objectTeamID    = objectTeamID,
        pos             = pos,
        angle           = { x = 0, y = angleY, z = 0 },
    })
end

function AddObjectState:DoMapGrid(x, y, z)
    if self.mapGrid == nil then
        return x, y, z
    end

    local objectDefID = self.objectDefIDs[math.random(1, #self.objectDefIDs)]
    local unitSizeX = self.bridge.ObjectDefs[objectDefID].footprintX
    local unitSizeZ = self.bridge.ObjectDefs[objectDefID].footprintZ
    if unitSizeX == nil or unitSizeZ == nil then
        if self.bridge.name == "unit" then
            local dim = Spring.GetUnitDefDimensions(objectDefID)
            unitSizeX = math.abs(dim.minx) + math.abs(dim.maxx)
            unitSizeZ = math.abs(dim.minz) + math.abs(dim.maxz)
        else
            unitSizeX = 4
            unitSizeZ = 4
        end
    end

    self.mapGrid.rows    = Game.mapSizeX / unitSizeX
    self.mapGrid.columns = Game.mapSizeZ / unitSizeZ

    local gridX, gridZ = self.mapGrid:GetGridPosition(x, z)
    local gridY = Spring.GetGroundHeight(gridX, gridZ)
    local blocking = Spring.TestBuildOrder(objectDefID, gridX, gridY, gridZ, 0)
    self.mapGrid:Draw(x, z, blocking)

    return gridX, gridY, gridZ
end

function AddObjectState:DrawWorld()
    if not self.objectDefIDs or #self.objectDefIDs == 0 then
        return
    end

    local mx, my = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(mx, my, true)
    if result ~= "ground" then
        return
    end

    gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(true)
    local shaderObj = SB.view.modelShaders:GetShader()
    gl.UseShader(shaderObj.shader)
    gl.Uniform(shaderObj.timeID, os.clock())
    gl.Uniform(shaderObj.teamColorID, Spring.GetTeamColor(self.team))

    local gridX, _, gridZ = self:DoMapGrid(coords[1], coords[2], coords[3])

    math.randomseed(self.randomSeed)
    for i = 1, self.amount do
        local objectDefID = self.objectDefIDs[math.random(1, #self.objectDefIDs)]
        local x, z = gridX, gridZ
        if self.x ~= 0 or self.z ~= 0 then
            x, z = self.x, self.z
        end
        if i ~= 1 then
            x = x + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
            z = z + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
        end
        local y = Spring.GetGroundHeight(x, z)
        local object = {
            objectDefID = objectDefID,
            objectTeamID = self.team,
            pos = { x = x, y = y, z = z },
            angleY = math.deg(self.angle),
        }
        self:DrawObject(object, self.bridge)
    end
    gl.UseShader(0)
end
