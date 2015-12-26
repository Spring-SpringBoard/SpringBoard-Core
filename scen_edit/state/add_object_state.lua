AddObjectState = AbstractEditingState:extends{}

function AddObjectState:init(editorView, objectDefIDs)
    AbstractEditingState.init(self, editorView)

    self.objectDefIDs = objectDefIDs
--     self.unitImages = unitImages
    self.x, self.y, self.z = 0, 0, 0
    self.angle = 0
    self.randomSeed = os.clock()
    self.mapGrid = MapGrid(100, 100)
    self.mapGrid.separatorSize = 2

    self.amount  = self.editorView.fields["amount"].value
	self.team    = self.editorView.fields["team"].value
end

function AddObjectState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            self.x, self.y, self.z = unpack(coords)
--             self.x, self.z = self.mapGrid:GetGridPosition(self.x, self.z)
--             self.y = Spring.GetGroundHeight(self.x, self.z)
            return true
        end
    elseif button == 3 then
--         self.unitImages.control:SelectItem(0)
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function AddObjectState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local dx = coords[1] - self.x
        local dz = coords[3] - self.z

        local len = math.sqrt(dx * dx + dz * dz)
        if len > 10 then
            self.angle = math.atan2(dx / len, dz / len) / math.pi * 180
        end
    end
end

function AddObjectState:MouseRelease(x, y, button)
    local commands = {}
    math.randomseed(self.randomSeed)
    for i = 1, self.amount do
        local objectDefID = self.objectDefIDs[math.random(1, #self.objectDefIDs)]
        local x, y, z = self.x, self.y, self.z
        if i ~= 1 then
            x = x + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
            z = z + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
        end
        local cmd = self.bridge.AddObjectCommand(objectDefID, x, y, z, self.team, self.angle)
        commands[#commands + 1] = cmd
    end

    local compoundCommand = CompoundCommand(commands)

    SCEN_EDIT.commandManager:execute(compoundCommand)
    self.x, self.y, self.z = 0, 0, 0
    self.angle = 0
    self.randomSeed = self.randomSeed + os.clock()
    return true
end

function AddObjectState:KeyPress(key, mods, isRepeat, label, unicode)
    if self:super("KeyPress", key, mods, isRepeat, label, unicode) then
        return true
    end
end

function AddObjectState:DrawWorld()
    if not self.objectDefIDs or #self.objectDefIDs == 0 then
        return
    end
    math.randomseed(self.randomSeed)
    local objectDefID = self.objectDefIDs[math.random(1, #self.objectDefIDs)]

    local x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)

    local unitSizeX = self.bridge.ObjectDefs[objectDefID].footprintX
    local unitSizeZ = self.bridge.ObjectDefs[objectDefID].footprintZ
    if unitSizeX == nil or unitSizeZ == nil then
        if self.bridge.bridgeName == "UnitBridge" then
            local dim = Spring.GetUnitDefDimensions(objectDefID)
            unitSizeX = math.abs(dim.minx) + math.abs(dim.maxx)
            unitSizeZ = math.abs(dim.minz) + math.abs(dim.maxz)
        else
            unitSizeX = 4
            unitSizeZ = 4
        end
    end
    if result == "ground" then

        local baseX, baseY, baseZ = unpack(coords)
        self.mapGrid.rows    = Game.mapSizeX / unitSizeX
        self.mapGrid.columns = Game.mapSizeZ / unitSizeZ
        local gridX, gridY, gridZ = baseX, baseY, baseZ
--         local gridX, gridZ = self.mapGrid:GetGridPosition(baseX, baseZ)
--         local gridY = Spring.GetGroundHeight(gridX, gridZ)
--         local blocking = Spring.TestBuildOrder(objectDefID, gridX, gridY, gridZ, 0)
--         self.mapGrid:Draw(baseX, baseZ, blocking)
--         math.randomseed(self.randomSeed)

        for i = 1, self.amount do
            local x, y, z = gridX, gridY, gridZ
            if self.x ~= 0 or self.y ~= 0 or self.z ~= 0 then
                x, y, z = self.x, self.y, self.z
            end
            if i ~= 1 then
                x = x + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
                z = z + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
            end
            gl.PushMatrix()

            gl.Translate(x, y, z)
            if self.x ~= 0 or self.y ~= 0 or self.z ~= 0 then
                gl.Rotate(self.angle, 0, 1, 0)
            end

            self.bridge.DrawObject(objectDefID, self.team)
            gl.PopMatrix()
        end
    end
end

-- Custom unit/feature classes
AddUnitState = AddObjectState:extends{}
function AddUnitState:init(...)
    AddObjectState.init(self, ...)
    self.bridge = unitBridge
end

AddFeatureState = AddObjectState:extends{}
function AddFeatureState:init(...)
    AddObjectState.init(self, ...)
    self.bridge = featureBridge
end